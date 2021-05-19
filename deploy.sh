#!/bin/bash
# Custom read functions that repeats the promt if the user doesn't enter anything
f_read() {
  read -p "$1" VALUE
  if [ -z $VALUE ]
  then
    VALUE=$(f_read "$1")
  fi
  echo $VALUE
}

f_read_env() {
  VALUE=$(f_read "$1")
  if [ $VALUE != "test" ] && [ $VALUE != "acceptatie" ] && [ $VALUE != "productie" ]
  then
    VALUE=$(f_read_env "$1")
  fi
  echo $VALUE
}

f_read_bool() {
  VALUE=$(f_read "$1")
  if [ $VALUE != "true" ] && [ $VALUE != "false" ]
  then
    VALUE=$(f_read_bool "$1")
  fi
  echo $VALUE
}

f_read_num() {
  VALUE=$(f_read "$1")
  if ! [[ $VALUE =~ ^[0-9]+$ ]]
  then
    VALUE=$(f_read_num "$1")
  fi
  echo $VALUE
}

f_read_mem() {
  VALUE=$(f_read "$1")
  if ! [[ `expr $VALUE % 128` == 0 ]]
  then
    VALUE=$(f_read_mem "$1")
  fi
  echo $VALUE
}

# Read variable values from user input
f_read_vars() {
  CUSTOMER=$(f_read "Customer name: ")
  ENVIRONMENT=$(f_read_env "Environment type [test/acceptatie/productie]: ")

  # Webserver stuff
  WEBSERVERS=$(f_read_bool "Do you want webservers [true/false]: ")
  if [ $WEBSERVERS == "true" ]
  then
    WEBSERVERS_AMOUNT=$(f_read_num "How many webservers do you want: ")
    WEBSERVERS_MEMORY=$(f_read_mem "How much ram do you want to allocate [increments of 128]: ")
  else
    WEBSERVERS_AMOUNT=0
    WEBSERVERS_MEMORY=0
  fi

  # Loadbalancer stuff
  LOADBALANCERS=$(f_read_bool "Do you want loadbalancers [true/false]: ")
  if [ $LOADBALANCERS == "true" ]
  then
    LOADBALANCERS_AMOUNT=$(f_read_num "How many loadbalancers do you want: ")
    LOADBALANCERS_MEMORY=$(f_read_mem "How much ram do you want to allocate [increments of 128]: ")
    LOADBALANCERS_PORT=$(f_read_num "On which port should the loadbalancer listen: ")
    LOADBALANCERS_STATS_PORT=$(f_read_num "On which port should the loadbalancer stats be available: ")
  else
    LOADBALANCERS_AMOUNT=0
    LOADBALANCERS_MEMORY=0
    LOADBALANCERS_PORT=80
    LOADBALANCERS_STATS_PORT=8080
  fi

  # Database server stuff
  DATABASESERVERS=$(f_read_bool "Do you want databseservers [true/false]: ")
  if [ $DATABASESERVERS == "true" ]
  then
    DATABASESERVERS_AMOUNT=$(f_read_num "How many database servers do you want: ")
    DATABASESERVERS_MEMORY=$(f_read_mem "How much ram do you want to allocate [increments of 128]: ")
  else
    DATABASESERVERS_AMOUNT=0
    DATABASESERVERS_MEMORY=0
  fi
  
  SUBNET=$(f_read "Which subnet should be used [x.x.x.]: ")
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
  if [ -f "$DEST/inventory.ini" ]
  then
    echo "inventory already exists, removing old inventory."
    rm $DEST/inventory.ini
  fi
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

# Function to destroy environment
f_destroy() {
  (cd "/cloudservice/customers/$1/$2" && vagrant destroy)
  rm -r "/cloudservice/customers/$1"
  exit 0
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
  exit 0
}

# Display help
f_display_help()
{
  echo "Usage: $0 [-h/-d]"
  echo -e "\t-h Display this help menu"
  echo -e "\t-d Destroy an environment"
  echo -e "\t\t-c Customer name of environment to destroy"
  echo -e "\t\t-e Environment name of environment to destroy"
  exit 1 # Exit script after printing help
}

#Check if arguments were supplied and set variables
while getopts "dhc:e:" opt
do
  case "$opt" in
    d )
      DESTROY="true"
      ;;
    c)
      PARAMETER_C="$OPTARG"
      ;;
    e )
      PARAMETER_E="$OPTARG"
      ;;
    h ) 
      f_display_help
      ;;
    ? )
      f_display_help # Show help in case a parameter is illegal
      ;;
  esac
done

# If the -d parameter is given -c -and -e should also be provided
if [ "$DESTROY" == "true" ]
then
  # If either c or e is empty(zero) display help
  if [ -z "$PARAMETER_C" ] || [ -z "$PARAMETER_E" ]
  then
    echo "Some or all of the parameters are empty";
    f_display_help
  else
    f_destroy $PARAMETER_C $PARAMETER_E
  fi
# If -d was not provided but -c or -e was display help
elif [ -z "$DESTROY" ]
then
  if [ ! -z "$PARAMETER_C" ] || [ ! -z "$PARAMETER_E" ]
  then
    echo "-c or -e requires the -d flag to be passed as well"
    f_display_help
  fi
fi

# Delpoy new env
f_main
