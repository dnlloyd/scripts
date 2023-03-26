#!/bin/bash

export ACCOUNT_ID=`aws sts get-caller-identity --query "Account" --output text`
export ROLE=$1

echo "Assuming ${1} role for tenant ${ACCOUNT_ID}..."

aws sts assume-role --role-arn=arn:aws:iam::${ACCOUNT_ID}:role/${ROLE} --role-session-name FOOBAR --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' --output=text >> output

OLDIFS=$IFS
filename='output'

while read line; do
  set $line  
  IFS=' '; set -f
  eval "array=($line)"
  count=0
  for x in "${array[@]}";do
    count=`expr $count + 1`
    case "$count" in
      "1") AWS_ACCESS_KEY_ID=$x
      echo AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
      ;;
      "2") AWS_SECRET_ACCESS_KEY=$x
      echo AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
      ;;
      "3") AWS_SESSION_TOKEN=$x
      echo AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN
      ;;
   esac
  done
done < $filename

IFS=$OLDIFS
rm -rf output

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN
