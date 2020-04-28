#!/bin/bash
# sc-send-resize-request.sh
#
# finds out who has started an instance (or all instances allocated on an hypervisor), as well as the tech contact for the
# VM's project and sends them an email via sendmail (or $MAIL_CMD) on behalf of the Name/email specified in the command line.
# It sends one email to each user, with the list of VM that needs to be resized, and one at each tech contact of the affected
# project, with a list of all the affected vms for each project.
# Requires: shell with admin OS credentials loaded and nova / openstack python clients installed, BASH 4
# Currently requires also a configured mail client supporting recipient as argument and mail headers on mail text.
# It uses sendmail by default, but you can override it passing your mail command as the $MAIL_CMD environment variable. 
# Also the mail message can be overridden passing $MESSAGE environment variable, that must contain headers+text mail message.
#
# - 2do: choose sending mail client
# - 2do: should warn about VMs started from a member of s3it and not belonging to our projects
# - 2do: choose mail text
# 
#

set -e

USAGE="$0 HYPERVISOR|VM_ID SENDER_EMAIL SENDER_NAME [--dry-run]"

[ -z $RESIZE_DUE_DATE ] && RESIZE_DUE_DATE=$(date -d "+ 3 weeks" "+%d of %B %Y") 

##################### ARG CHECK
# check if a openstack username is set...
[ -z "$OS_USERNAME" ] && {
    echo "Error: No openstack username set."
    echo "Did you load your OpenStack credentials??"
    exit 42
}

[ 3 -ne $# ] && {
    if [ 4 -eq $# ]; then
        [ "--dry-run" = "$4" ] || { 
            echo "Syntax Error: Wrong argument number 5" >&2
            echo $USAGE
            exit 1
        }
        DRY_RUN=true;
    else
        echo "Syntax Error: Wrong arguments" >&2
        echo $USAGE
        exit 1
    fi
}

ARG1=$(echo $1 | tr '[:upper:]' '[:lower:]')
echo $ARG1
#check if arg 1 is an hypervisor or an UUID
if [[ $ARG1 =~ ^node-[a-z][0-9][0-9]?-[0-9][0-9](-[0-9][0-9])?$ ]]; then
    HYPERVISOR=$ARG1
elif [[ $ARG1 =~ ^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$ ]]; then
    VM_ID=$ARG1
else
    echo "Error: Invalid argument: '$1'" >&2
    echo $USAGE
    exit 2
fi


#sender argument is here in case you need to override the sender field of the message.
#check if arg 3 is a valid sender..
[[ "$2" =~ ^[a-z0-9.]+@.*uzh\.ch$ ]] || {
    echo "Error: Invalid sender email: '$3'" >&2
    echo $USAGE
    exit 3
}
SENDER_EMAIL="$2"

[[ "$3" =~ ^[A-Z][a-z]+\ [A-Z][a-z]+$ ]] || {
    echo "Error: Invalid sender name: '$4'" >&2
    echo $USAGE
    exit 4
}

SENDER_NAME="$3"

#sendmail or mail or mutt or ??!!
# I'd use sendmail...
# You could override this passing your mail command as an environment variable. Must support recipient as argument.
[ -z "$MAIL_CMD" ] && MAIL_CMD="sendmail"
    
echo -n "Using "
[ -z $HYPERVISOR ] || echo Hypervisor hostname 
[ -z $VM_ID ] || echo VM UUID


if [ ! -z $HYPERVISOR ]; then
    vm_id_list="$(nova hypervisor-servers $HYPERVISOR | egrep -o '[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}')"
else
    vm_id_list="$VM_ID"
fi

[ -z "$vm_id_list" ] && { echo "ERROR: empty vm_id_list!"; exit 5; }
    
declare -A users=()
declare -A contacts=()

##################
send_message () {
    # combines head, vm_info (given as parameter) and tail and sends via MAIL_CMD
    message_head=$(cat <<Endofmessagehead
From: "$SENDER_NAME" <$SENDER_EMAIL>
Reply-To: help@s3it.uzh.ch
To: $os_user_email
Subject: Sciencecloud instance(s) require "Resize" before $RESIZE_DUE_DATE
Dear ScienceCloud user,

This is an automated message to inform you that the virtual machines listed below require a "Resize" action to be performed at your discretion before $RESIZE_DUE_DATE.


Endofmessagehead
    )
    message_tail=$(cat <<Endofmessagetail

"Resizing" your ScienceCloud instance allows you to change its flavor and that is required because the hardware your VM is running on will be soon switched off and decommissioned.
Since February 2020 new hardware has been added (link to the newsletter message - it should be public) and correspondingly flavors with an "-hpcv3" suffix have been created to replace the old "-hpc" flavors: they should be selected as a destination during the resize process.
It is possible to resize without changing the amount of vCPUs and RAM allocated. For example: it is possible to resize a "4cpu-16ram-hpc" instance to a "4cpu-16ram-hpcv3" one.
The price for the "-hpcv3" flavors is the same as the corresponding "-hpc" flavors (assuming the number of vCPU and RAM is kept the same).

When the "resize" takes place, the instance will REBOOT itself.

To "resize" an instance you can follow the instructions in the ScienceCloud user documentation (accessible from UZH network or via VPN) at https://s3itwiki.uzh.ch/display/clouddoc/How+to+resize+your+instance

A brief summary follows:
- login to the ScienceCloud website and choose the "Instances" page
- Select "Resize instance" from the dropdown menu on the right (next to the "Create snapshot" button) in the row corresponding to the instance name
- Select a new flavor with the "-hpcv3" suffix
- Hit "resize" button and the instance will reboot into the new flavor
- Open a terminal and check that you can connect to your instance
- (optional) If you have attached additional volumes to your VM follow the additional steps you can find here: https://s3itwiki.uzh.ch/display/clouddoc/How+to+resize+your+instance.
- If the checks are successful, confirm the resize in the "Instances" page of the Science Cloud website by clicking on the Confirm Resize button.
 
IMPORTANT NOTE: If you do not perform the resize before $RESIZE_DUE_DATE your instance will be administratively resized!
This warning message is final: a message will confirm the resize has taken place if no action is taken on your side.

The $user_or_contact involved has been warned as well. You might want to coordinate with him to perform the task.

Thank you in advance for your cooperation. If you have questions or need further support please write to help@s3it.uzh.ch
        
Best regards,
--
On behalf of S3IT,
$SENDER_NAME
Service and Support for Science IT (S3IT)
University of Zurich
Endofmessagetail
    )
    message="$message_head"$'\n'"$1""$message_tail"
    echo
    echo "$message"
    echo
    echo "Mailing with \"$MAIL_CMD $os_user_email\""

    if [ "$DRY_RUN" = "true" ]; then
        echo
        echo "-----> THIS IS A DRY RUN - NO MAIL WAS SENT!!!!"
        echo
    else
        #send message
        echo "$message" | $MAIL_CMD $os_user_email
        echo
        echo "-----> The message was sent! (retcode $?)"
        echo
    fi

}
#####################

# add each vm info to an array of "users" and of "contacts"
# key of array is the user email, while each row is a list of the info: "vm_id instance_name project_id project_name"
# while the contact row (with key tech contact email) has same type of values + the user_id"
# a user or a tech contact receive at most 2 emails, if he owns and affected vm and is a contact at the same time.
for vm_id in $vm_id_list; do
    os_server_show_out=$(openstack server show $vm_id)
    echo "$os_server_show_out"
    # create entry in "users"
    os_user_id=$(echo "$os_server_show_out" | grep user_id | tr -d '|' | sed 's/user_id //g' | tr -d '[:blank:]')
    os_project_id=$(echo "$os_server_show_out" | grep project_id | tr -d '|' | sed 's/project_id //g' | tr -d '[:blank:]')
    vm_name=$(echo "$os_server_show_out" | grep -A 1 key_name | tail -n1 | tr -d '|' | sed 's/name //' | tr -d '[:blank:]')
    #os_user_email=$(openstack user show $os_user_id | grep email | tr -d '|' | tr -d '[:blank:]' | sed 's/^email//')
    os_project_show_out=$(openstack project show $os_project_id)
    os_project_name=$(echo "$os_project_show_out" | grep name | tr -d '|' | tr -d '[:blank:]' | sed 's/^name//')  
    os_project_contact=$(echo "$os_project_show_out" | grep contact_email | tr -d '|' | tr -d '[:blank:]' | sed 's/^contact_email//') 

    if [ -z "$vm_name" ] || [ -z "$os_project_id" ] || [ -z "$os_project_name" ] || [ -z "$os_user_id" ]; then
        echo "WARNING: Could not retrieve full info for '$vm_id'!"
        echo "Skipping VM..."
        vm_info_missing_list="$vm_info_missing_list $vm_id"
        continue
    fi

    #each entry is one line
    users[$os_user_id]+="$(echo -e $vm_name\\t$vm_id\\t$os_project_id\\t$os_project_name)"$'\n'
    contacts[$os_project_contact]+="$(echo -e $os_user_id\\t\\t$vm_name\\t$vm_id\\t$os_project_name\\t$os_project_id)"$'\n'
done

# send mail to instance owners
user_or_contact="technical contact of the project(s)"
    
for user in "${!users[@]}";do
    echo "${users[$user]}"
    os_user_email=$(openstack user show $user | grep email | tr -d '|' | tr -d '[:blank:]' | sed 's/^email//')
    if [ -z "$os_user_email" ]; then
        echo "WARNING: Could not retrieve mail address for '$user'!"
        echo "Skipping send mail..."
        user_address_missing_list="$user_address_missing_list $user"
        continue
    fi
    echo "Sending mail to $os_user_email..."
    
    send_message "instance name                   instance uuid                   project name                project uuid
${users[$user]}"
done

# send mail to tech contacts
user_or_contact="user that launched the instance(s)"
for contact in "${!contacts[@]}"; do
    echo "${contacts[$contact]}"
    if [ -z "$contact" ]; then
        echo "WARNING: Could not retrieve mail address for '$contact'!"
        echo "Skipping send mail..."
        contact_address_missing_list="$contact_address_missing_list $contact"
        continue
    fi
    echo "Sending mail to $contact..."
    
    send_message "shortname       instance name                   instance uuid                   project name                project uuid
${contacts[$contact]}"

done

[ -z "$vm_info_missing_list" ] || echo "WARNING: Missing VM info(es)!" && echo $vm_info_missing_list
[ -z "$user_address_missing_list" ] || echo "WARNING: Missing user address(es)!" && echo $user_address_missing_list
[ -z "$contact_address_missing_list" ] || echo "WARNING: Missing contact address(es)!" && echo $contact_address_missing_list
