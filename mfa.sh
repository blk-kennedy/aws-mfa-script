#!/bin/bash
#
# Sample for getting temp session token from AWS STS
#
# aws --profile youriamuser sts get-session-token --duration 3600 \
# --serial-number arn:aws:iam::012345678901:mfa/user --token-code 012345
#
# Once the temp token is obtained, you'll need to feed the following environment
# variables to the aws-cli:
#
# export AWS_ACCESS_KEY_ID='KEY'
# export AWS_SECRET_ACCESS_KEY='SECRET'
# export AWS_SESSION_TOKEN='TOKEN'

AWS_CLI=`which aws`

if [ $? -ne 0 ]; then
  echo "AWS CLI is not installed; exiting"
  exit 1
else
  echo "Using AWS CLI found at $AWS_CLI"
fi

# 1 or 2 args ok
if [[ $# -ne 1 && $# -ne 2 ]]; then
  echo "Usage: $0 <AWS_CLI_PROFILE> <MFA_TOKEN_CODE>"
  echo "Where:"
  echo "   <MFA_TOKEN_CODE> = Code from virtual MFA device"
  echo "   <AWS_CLI_PROFILE> = aws-cli profile usually in $HOME/.aws/config"
  exit 2
fi

echo "Reading config..."

AWS_CLI_PROFILE=${1:-default}
MFA_TOKEN_CODE=$2

if [ -r ~/aws-mfa-script/mfa.json ]; then
  ARN_OF_MFA=`jq -r --arg PROFILE $AWS_CLI_PROFILE '.[$PROFILE]' ~/aws-mfa-script/mfa.json`
else
  echo "No config found.  Please create your mfa.cfg.  See README.txt for more info."
  exit 2
fi

echo "AWS-CLI Profile: $AWS_CLI_PROFILE"
echo "MFA ARN: $ARN_OF_MFA"
echo "MFA Token Code: $MFA_TOKEN_CODE"

echo "Your Temporary Creds:"

RESULT=$(aws --profile $AWS_CLI_PROFILE sts get-session-token --duration 129600 --serial-number $ARN_OF_MFA --token-code $MFA_TOKEN_CODE --output text)

echo ${RESULT} | awk '{printf("export AWS_ACCESS_KEY_ID=\"%s\"\nexport AWS_SECRET_ACCESS_KEY=\"%s\"\nexport AWS_SESSION_TOKEN=\"%s\"\nexport AWS_SECURITY_TOKEN=\"%s\"\n",$2,$4,$5,$5)}' | tee ~/aws-mfa-script/.token_file

AWS_ACCESS_KEY_ID=$(echo ${RESULT} | cut -d" " -f2)
AWS_SECRET_ACCESS_KEY=$(echo ${RESULT} | cut -d" " -f4)
AWS_SESSION_TOKEN=$(echo ${RESULT} | cut -d" " -f5)

MFA_PROFILE="${1}-mfa"

aws configure set profile.${MFA_PROFILE}.aws_access_key_id ${AWS_ACCESS_KEY_ID}
aws configure set profile.${MFA_PROFILE}.aws_secret_access_key ${AWS_SECRET_ACCESS_KEY}
aws configure set profile.${MFA_PROFILE}.aws_session_token ${AWS_SESSION_TOKEN}
