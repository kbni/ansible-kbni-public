#!/bin/bash

REMOTE_USER="root"
DHCP_SERVER="10.0.0.253"
LOOP="yes"

for arg in "$@"; do
    [[ "$arg" = "noloop" ]] && LOOP=no
done

while :; do
    ssh -q $REMOTE_USER@$DHCP_SERVER arp -n | grep '00:0c:' | cut -f1 -d' ' | while read test_ip; do
        if ! nc -z -w1 $test_ip 22 &>/dev/null; then
            echo "port 22 not open"
            continue
        fi

        test_hostname=$(ssh -o StrictHostKeyChecking=no $REMOTE_USER@$test_ip hostname -f)

        touch slurped
        mkdir -p private/etc

        if grep --silent $test_hostname slurped; then
            # already slurped
            continue
        fi

        echo -n "discovered ${test_ip} (${test_hostname}).."

        if [ "$test_hostname" = "debian" ]; then
            echo ". not actually a hostname"
            continue
        fi
       
        if ! ssh -o StrictHostKeyChecking=no $REMOTE_USER@$test_ip test -f /usr/local/sbin/hostname-prep.sh; then
            echo ". hostname-prep.sh not present"
            continue
        fi

        echo "$test_hostname" | cat - slurped > slurped.tmp && mv slurped.tmp slurped
        echo "$test_ip $test_hostname ${test_hostname/.*/} # slurped on $(date)" >> private/etc/dnsmasq.hosts
        echo ". slurped. :)"

    done
    if [ "$LOOP" = "yes" ]; then
        sleep 3
    else
        break
    fi
done

