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
  if [ "$ENVIRONMENT" == "acceptatie" ] || [ "$ENVIRONMENT" == "productie" ]
  then
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
  else
    LOADBALANCERS="false"
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
  echo "ENVIRONMENT=$ENVIRONMENT" >> $DEST/envvars.txt
  echo "SUBNET=$SUBNET" >> $DEST/envvars.txt
  echo "WEBSERVERS=$WEBSERVERS" >> $DEST/envvars.txt
  echo "WEBSERVERS_AMOUNT=$WEBSERVERS_AMOUNT" >> $DEST/envvars.txt
  echo "WEBSERVERS_MEMORY=$WEBSERVERS_MEMORY" >> $DEST/envvars.txt
  echo "LOADBALANCERS=$LOADBALANCERS" >> $DEST/envvars.txt
  echo "LOADBALANCERS_AMOUNT=$LOADBALANCERS_AMOUNT" >> $DEST/envvars.txt
  echo "LOADBALANCERS_MEMORY=$LOADBALANCERS_MEMORY" >> $DEST/envvars.txt
  echo "LOADBALANCERS_PORT=$LOADBALANCERS_PORT" >> $DEST/envvars.txt
  echo "LOADBALANCERS_STATS_PORT=$LOADBALANCERS_STATS_PORT" >> $DEST/envvars.txt
  echo "DATABASESERVERS=$DATABASESERVERS" >> $DEST/envvars.txt
  echo "DATABASESERVERS_AMOUNT=$DATABASESERVERS_AMOUNT" >> $DEST/envvars.txt
  echo "DATABASESERVERS_MEMORY=$DATABASESERVERS_MEMORY" >> $DEST/envvars.txt
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
}

# Function to edit environment
f_edit() {
  DEST="/cloudservice/customers/$1/$2"
  
  # Retrieve environment info
  source "$DEST/envvars.txt"

  # Webserver stuff
  WEBSERVERS=$(f_read_bool "Do you want to change webservers [true/false]: ")
  if [ $WEBSERVERS == "true" ]
  then
    WEBSERVERS_AMOUNT=$(f_read_num "How many webservers do you want [You currently have $WEBSERVERS_AMOUNT]: ")
    WEBSERVERS_MEMORY=$(f_read_mem "How much ram do you want to allocate [increments of 128, currently at $WEBSERVERS_MEMORY]: ")
  fi

  # Loadbalancer stuff
  if [ "$ENVIRONMENT" == "acceptatie" ] || [ "$ENVIRONMENT" == "productie" ]
  then
    LOADBALANCERS=$(f_read_bool "Do you want to change loadbalancers [true/false]: ")
    if [ $LOADBALANCERS == "true" ]
    then
      LOADBALANCERS_AMOUNT=$(f_read_num "How many loadbalancers do you want [You currently have $LOADBALANCERS_AMOUNT]: ")
      LOADBALANCERS_MEMORY=$(f_read_mem "How much ram do you want to allocate [increments of 128, currently at $LOADBALANCERS_MEMORY]: ")
      LOADBALANCERS_PORT=$(f_read_num "On which port should the loadbalancer listen [Current is $LOADBALANCERS_PORT]: ")
      LOADBALANCERS_STATS_PORT=$(f_read_num "On which port should the loadbalancer stats be available [Current is $LOADBALANCERS_STATS_PORT]: ")
    fi
  fi

  # Database server stuff
  echo "!WARNING! Editing your database servers could result in data loss"
  DATABASESERVERS=$(f_read_bool "Do you want to change databseservers [true/false]: ")
  if [ $DATABASESERVERS == "true" ]
  then
    DATABASESERVERS_AMOUNT=$(f_read_num "How many database servers do you want [You currently have $DATABASESERVERS_AMOUNT]: ")
    DATABASESERVERS_MEMORY=$(f_read_mem "How much ram do you want to allocate [increments of 128, currently at $DATABASESERVERS_MEMORY]: ")
  fi

  rm "$DEST/Vagrantfile"
  rm "$DEST/envvars.txt"
  rm "$DEST/inventory.ini"
  rm "$DEST/ansible.cfg"
  f_copy_files
  sed -i "s/{{ hostname_base }}/$1-$2-/g" "$DEST/Vagrantfile"
  sed -i "s/{{ subnet }}/$SUBNET/g" "$DEST/Vagrantfile"
  f_webservers
  f_loadbalancers
  f_databaseservers
  (cd $DEST && vagrant reload)
  (cd $DEST && ansible-playbook /cloudservice/playbooks/site.yml)
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
  echo "Usage: $0 [-h/-D/-E]"
  echo -e "\t-h Display this help menu"
  echo -e "\t-E Edit an environment"
  echo -e "\t\t-c Customer name of environment to destroy"
  echo -e "\t\t-e Environment name of environment to destroy"
  echo -e "\t-D Destroy an environment"
  echo -e "\t\t-c Customer name of environment to destroy"
  echo -e "\t\t-e Environment name of environment to destroy"
  exit 1 # Exit script after printing help
}

#Check if arguments were supplied and set variables
while getopts "DEhc:e:" opt
do
  case "$opt" in
    D )
      DESTROY="true"
      ;;
    E )
      EDIT="true"
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

if [ "$DESTROY" == "true" ] && [ "$EDIT" == "true" ]
then
  echo "Two conflicting parameters have been provided";
  f_display_help
fi

# If the -d parameter is given -c -and -e should also be provided
if [ "$DESTROY" == "true" ] || [ "$EDIT" == "true" ]
then
  # If either c or e is empty(zero) display help
  if [ -z "$PARAMETER_C" ] || [ -z "$PARAMETER_E" ]
  then
    echo "Some or all of the parameters are empty";
    f_display_help
  fi
# If -d was not provided but -c or -e was display help
elif [ -z "$DESTROY" ] && [ -z "$EDIT" ]
then
  if [ ! -z "$PARAMETER_C" ] || [ ! -z "$PARAMETER_E" ]
  then
    echo "-c or -e requires the -d flag to be passed as well"
    f_display_help
  fi
fi

if [ "$DESTROY" == "true" ]
then
  # Destroy existing env
  f_destroy $PARAMETER_C $PARAMETER_E
  exit 0
elif [ "$EDIT" == "true" ]
then
  # Edit existing env
  f_edit $PARAMETER_C $PARAMETER_E
else
  # Delpoy new env
  f_main
fi
