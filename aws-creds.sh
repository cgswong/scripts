#!/bin/bash
# Basic wrapper script to get all AWS credentials via AWS SSO and AWS CLIv2

PROFILES=(ct-mgmt-admin ct-log-admin ct-audit-admin ct-netw-admin ct-sharedsvc-admin ct-sbx-admin ct-qa-admin ct-demo-admin)
for aws_profile in "${PROFILES[@]}"; do
  echo "Setting AWS profile: ${aws_profile}"
  aws sso login --profile ${aws_profile} --no-cli-auto-prompt
done
unset PROFILES
unset aws_profile
