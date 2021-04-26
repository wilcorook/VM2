#!/bin/bash
# Declare variables
CUSTOMER="henk"
ENVIRONMENT="test"
DEST="/cloudservice/customers/$CUSTOMER/$ENVIRONMENT"
SUBNET="10.2.1."
WEBSERVERS=true
WEBSERVERS_AMOUNT=2
WEBSERVERS_MEMORY=2048
LOADBALANCERS=true
LOADBALANCERS_AMOUNT=1
LOADBALANCERS_MEMORY=2048

# Copy and create files in destination dir
f_copy_files() {
  mkdir --parents $DEST
  cp /cloudservice/templates/test $DEST/Vagrantfile
  cp /cloudservice/templates/ansible.cfg $DEST/ansible.cfg
  f_build_inventory
}

# Templating for webservers
f_webservers() {
  sed -i "s/{{ webservers }}/$WEBSERVERS/g" "$DEST/Vagrantfile"
  sed -i "s/{{ webserver_amount }}/$WEBSERVERS_AMOUNT/g" "$DEST/Vagrantfile"
  sed -i "s/{{ webserver_memory }}/$WEBSERVERS_MEMORY/g" "$DEST/Vagrantfile"
}

# Templating for loadbalancers
f_loadbalancers() {
  sed -i "s/{{ loadbalancers }}/$LOADBALANCERS/g" "$DEST/Vagrantfile"
  sed -i "s/{{ loadbalancer_amount }}/$LOADBALANCERS_AMOUNT/g" "$DEST/Vagrantfile"
  sed -i "s/{{ loadbalancer_memory }}/$LOADBALANCERS_MEMORY/g" "$DEST/Vagrantfile"
}

# Create and fill Ansible inventory
f_build_inventory() {
  # Create file
  touch $DEST/inventory.ini
  # If webservers are created add them to inventory
  if [ $WEBSERVERS ]
  then
    echo "[webservers]" >> $DEST/inventory.ini
    COUNTER=0
    while [ $COUNTER -lt $WEBSERVERS_AMOUNT ]
    do
      # add 5 because that is where the range for webservers starts
      echo "$SUBNET`expr $COUNTER + 5`" >> $DEST/inventory.ini
      COUNTER=`expr $COUNTER + 1`
    done
  fi
  # If loadbalancers are created add them to inventory
  if [ $LOADBALANCERS ]
  then
    echo "[loadbalancers]" >> $DEST/inventory.ini
    COUNTER=0
    while [ $COUNTER -lt $LOADBALANCERS_AMOUNT ]
    do
      # add 5 because that is where the range for webservers starts
      echo "$SUBNET`expr $COUNTER + 10`" >> $DEST/inventory.ini
      COUNTER=`expr $COUNTER + 1`
    done
  fi
}

# Main function
f_main() {
  f_copy_files
  sed -i "s/{{ hostname_base }}/$CUSTOMER-$ENVIRONMENT-/g" "$DEST/Vagrantfile"
  sed -i "s/{{ subnet }}/$SUBNET/g" "$DEST/Vagrantfile"
  f_webservers
  f_loadbalancers
}

f_main
