#!/bin/bash
f_cleanup() {
    sudo cp /etc/hosts.bak /etc/hosts
    cp ~/.ssh/known_hosts.bak ~/.ssh/known_hosts
    rm -r /cloudservice/customers/henk
    vagrant global-status --prune
}

f_cleanup