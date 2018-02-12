#!/bin/bash
if [! -z $1 && ! -z $2 ]
then
  for url in $(wp site list --format=csv --fields=url | tail -n +2)
  do
    wp --url=$url user set-role $1 $2
  done
else
  echo "Command requires to parameters (username and role). Try again like add-user-to-all-sites.sh myusername administrator"
fi
