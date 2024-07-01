#!/bin/bash

# Usage
# aws_assume_script.sh Role-Name [Account-ID]

if [[ -z $2 ]]
then
  export ACCOUNT_ID=`aws sts get-caller-identity --query "Account" --output text`
else
  export ACCOUNT_ID=$2
fi

export ROLE=$1

echo "Assuming ${1} role for account ${ACCOUNT_ID}..."
aws sts assume-role --role-arn=arn:aws:iam::${ACCOUNT_ID}:role/${ROLE} --role-session-name breakglass --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' --output=text >> output

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
      "1") 
        AWS_ACCESS_KEY_ID=$x
        TF_VAR_vault_aws_access_key_id=$x
        echo AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
        ;;
      "2") 
        AWS_SECRET_ACCESS_KEY=$x
        TF_VAR_vault_aws_secret_access_key=$x
        echo AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
        ;;
      "3")
        AWS_SESSION_TOKEN=$x
        TF_VAR_vault_aws_session_token=$x
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

export TF_VAR_vault_aws_access_key_id
export TF_VAR_vault_aws_secret_access_key
export TF_VAR_vault_aws_session_token
