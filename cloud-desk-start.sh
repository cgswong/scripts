#!/bin/bash
# SSH into AWS Cloud Desktop.

kinit && mwinit --aea
/usr/bin/ssh-add -K -t 72000
ssh -A clouddesk
