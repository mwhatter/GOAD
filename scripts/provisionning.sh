#!/bin/bash

ERROR=$(tput setaf 1; echo -n "[!]"; tput sgr0)
OK=$(tput setaf 2; echo -n "[✓]"; tput sgr0)
INFO=$(tput setaf 3; echo -n "[-]"; tput sgr0)

RESTART_COUNT=0
MAX_RETRY=3

#ANSIBLE_COMMAND="ansible-playbook -i ../ad/azure-sevenkingdoms.local/inventory"
echo "[+] Current folder $(pwd)"
echo "[+] Ansible command : $ANSIBLE_COMMAND"

function run_ansible {
    if [ $RESTART_COUNT -eq $MAX_RETRY ]; then
        echo "$ERROR $MAX_RETRY retries occurred, moving to next playbook..."
        RESTART_COUNT=0
        return 1
    fi

    echo "[+] Restart counter: $RESTART_COUNT"
    let "RESTART_COUNT += 1"

    echo "$OK Running command: $ANSIBLE_COMMAND $1"

    timeout 20m $ANSIBLE_COMMAND $1
    exit_code=$?

    if [ $exit_code -eq 4 ]; then
        echo "$ERROR Error while running: $ANSIBLE_COMMAND $1"
        echo "$ERROR Some hosts were unreachable, we are going to retry"
        run_ansible $1

    elif [ $exit_code -eq 124 ]; then
        echo "$ERROR Error while running: $ANSIBLE_COMMAND $1"
        echo "$ERROR Command has reached the timeout limit of 20 minutes, we are going to retry"
        run_ansible $1

    elif [ $exit_code -eq 0 ]; then
        echo "$OK Command successfully executed"
        RESTART_COUNT=0
        return 0

    else
        echo "$ERROR Fatal error from ansible with exit code: $exit_code"
        echo "$ERROR We are going to retry"
        run_ansible $1
    fi
}

# We run all the recipes separately to minimize failure
playbooks=("build.yml" "ad-servers.yml" "ad-parent_domain.yml" "ad-child_domain.yml" "ad-members.yml" "ad-trusts.yml" "ad-data.yml" "ad-gmsa.yml" "laps.yml" "ad-relations.yml" "adcs.yml" "ad-acl.yml" "servers.yml" "security.yml" "vulnerabilities.yml" "reboot.yml")

echo "[+] Running all the playbook to setup the lab"
for playbook in "${playbooks[@]}"; do
    run_ansible $playbook
    if [ $? -ne 0 ]; then
        echo "$INFO Moving to next playbook after retry limit reached for $playbook"
    fi

    # Special case for waiting after child domain creation
    if [ "$playbook" = "ad-child_domain.yml" ]; then
        echo "$INFO Waiting 5 minutes for the child domain to be ready"
        sleep 5m
    fi
done

echo "$OK your lab is successfully set up! Have fun ;)"
