#!/usr/bin/env bash

CMD="$@"
: ${AWS_ACCOUNT_ID:="123456542501"}
: ${AWS_ROLE_NAME:="myrole"}
: ${AWS_PROFILE_NAME:="myrole-np"}
: ${ROLE_SESSION_NAME:="nonprd"}

ASSUME_ROLE="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${AWS_ROLE_NAME}"
TMP_FILE="/tmp/.aws-credentials.tmp"

aws --profile=${AWS_PROFILE_NAME} sts assume-role --output json --role-arn ${ASSUME_ROLE} --role-session-name ${ROLE_SESSION_NAME} &> ${TMP_FILE}

ACCESS_KEY=$(cat ${TMP_FILE} | jq -r ".Credentials.AccessKeyId")
SECRET_KEY=$(cat ${TMP_FILE} | jq -r ".Credentials.SecretAccessKey")
SESSION_TOKEN=$(cat ${TMP_FILE} | jq -r ".Credentials.SessionToken")
EXPIRATION=$(cat ${TMP_FILE} | jq -r ".Credentials.Expiration")

echo "Retrieved temp access key ${ACCESS_KEY} for role ${ASSUME_ROLE}. Key will expire at ${EXPIRATION}"

TF_VAR_aws_access_key=${ACCESS_KEY} TF_VAR_aws_secret_key=${SECRET_KEY} TF_VAR_aws_session_token=${SESSION_TOKEN} ${CMD}
