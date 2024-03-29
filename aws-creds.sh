#!/bin/bash
# Basic wrapper script to get all AWS credentials via AWS SSO and AWS CLIv2

PROFILES=(
  ct-audit-admin
  ct-demo-admin
  ct-log-admin
  ct-mgmt-admin
  ct-netw-admin
  ct-qa-admin
  ct-sbx-admin
  ct-sharedsvc-admin
)
for aws_profile in "${PROFILES[@]}"; do
  echo "Setting AWS profile: ${aws_profile}"
  aws sso login --profile ${aws_profile} --no-cli-auto-prompt
done
unset PROFILES
unset aws_profile
