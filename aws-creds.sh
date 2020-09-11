#!/bin/bash
# Basic wrapper script to get all AWS credentials via AWS SSO and AWS CLIv2

PROFILES=(ct-mgmt ct-log-archive ct-audit ct-network ct-shared-services ct-sandbox)
for aws_profile in "${PROFILES[@]}"; do
  echo "Setting AWS profile: ${aws_profile}"
  aws sso login --profile ${aws_profile}
done
unset PROFILES
unset aws_profile
