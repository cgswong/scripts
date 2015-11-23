#! /usr/bin/env bash
# Enable port forwarding to get around firewall restrictions
# and connect to Freenode on IRC

# Use localhost:2000 to connect via itsajump-me server (see ~/.ssh/config) to freenode:6667
ssh -L 2000:irc.freenode.net:6667 itsajump-me -N
