#!/bin/bash
f_read() {
  read -p "$1" VALUE
  if [ -z $VALUE ]
  then
    VALUE=$(f_read "$1")
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

ENVIRONMENT=$(f_read_mem "Amount: ")
echo $ENVIRONMENT