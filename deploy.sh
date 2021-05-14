#!/bin/bash
# Declare variables default values
SUBNET="10.2.1."
WEBSERVERS=true
WEBSERVERS_AMOUNT=2
WEBSERVERS_MEMORY=1024
LOADBALANCERS=true
LOADBALANCERS_AMOUNT=1
LOADBALANCERS_MEMORY=2048
LOADBALANCERS_PORT=80
LOADBALANCERS_STATS_PORT=8080
DATABASESERVERS=true
DATABASESERVERS_AMOUNT=1
DATABASESERVERS_MEMORY=2048

# Read variable values from user input
f_read_vars() {
  read -p "Customer name: " CUSTOMER
  read -p "Environment name: " ENVIRONMENT
  DEST="/cloudservice/customers/$CUSTOMER/$ENVIRONMENT"
}

# Copy and create files in destination dir
f_copy_files() {
  mkdir --parents $DEST
  cp /cloudservice/templates/Vagrantfile $DEST/Vagrantfile
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

# Templating for databaseservers
f_databaseservers() {
  sed -i "s/{{ databaseservers }}/$DATABASESERVERS/g" "$DEST/Vagrantfile"
  sed -i "s/{{ databaseserver_amount }}/$DATABASESERVERS_AMOUNT/g" "$DEST/Vagrantfile"
  sed -i "s/{{ databaseserver_memory }}/$DATABASESERVERS_MEMORY/g" "$DEST/Vagrantfile"
}

# Create and fill Ansible inventory
f_build_inventory() {
  # Create file
  touch $DEST/inventory.ini
  # If webservers are created add them to inventory
  if [ $WEBSERVERS == "true" ]
  then
    echo "[webservers]" >> $DEST/inventory.ini
    COUNTER=0
    while [ $COUNTER -lt $WEBSERVERS_AMOUNT ]
    do
      # add 5 because that is where the range for webservers starts
      echo "$SUBNET`expr $COUNTER + 20`" >> $DEST/inventory.ini
      COUNTER=`expr $COUNTER + 1`
    done
    echo "" >> $DEST/inventory.ini
  fi
  # If loadbalancers are created add them to inventory
  if [ $LOADBALANCERS == "true" ]
  then
    echo "[loadbalancers]" >> $DEST/inventory.ini
    COUNTER=0
    while [ $COUNTER -lt $LOADBALANCERS_AMOUNT ]
    do
      # add 5 because that is where the range for webservers starts
      echo "$SUBNET`expr $COUNTER + 2`" >> $DEST/inventory.ini
      COUNTER=`expr $COUNTER + 1`
    done
    echo "" >> $DEST/inventory.ini
    echo "[loadbalancers:vars]" >> $DEST/inventory.ini
    echo "bind_port=$LOADBALANCERS_PORT" >> $DEST/inventory.ini
    echo "stats_port=$LOADBALANCERS_STATS_PORT" >> $DEST/inventory.ini
    echo "" >> $DEST/inventory.ini
  fi
  # If databaseservers are created add them to inventory
  if [ $DATABASESERVERS == "true" ]
  then
    echo "[databaseservers]" >> $DEST/inventory.ini
    COUNTER=0
    while [ $COUNTER -lt $DATABASESERVERS_AMOUNT ]
    do
      # add 5 because that is where the range for webservers starts
      echo "$SUBNET`expr $COUNTER + 10`" >> $DEST/inventory.ini
      COUNTER=`expr $COUNTER + 1`
    done
    echo "" >> $DEST/inventory.ini
  fi
}

# Main function
f_main() {
  f_read_vars
  f_copy_files
  sed -i "s/{{ hostname_base }}/$CUSTOMER-$ENVIRONMENT-/g" "$DEST/Vagrantfile"
  sed -i "s/{{ subnet }}/$SUBNET/g" "$DEST/Vagrantfile"
  f_webservers
  f_loadbalancers
  f_databaseservers
  (cd $DEST && vagrant up)
  (cd $DEST && ansible-playbook /cloudservice/playbooks/site.yml)
}

f_main
