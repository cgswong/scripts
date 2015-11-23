#!/bin/bash
# ########################################################################
# NAME: rm-github.sh
# DESC: Script to completely remove Github from Max OS X. Reference:
#       https://gist.github.com/naomik/11245234
#
# LOG:
# yyyy/mm/dd [name] [version]: [notes]
# 2014/10/14 cgwong v0.1.0: Initial creation.
# ########################################################################

function remove_dir () {
  rm -rf "$1_"
 
  if [ -d "$1" ]; then
    mv "$1" "$1_"
  fi
}
 
echo "*** Removing saved user, repositories, and orgs…"
 
remove_dir "${HOME}/Library/Application Support/GitHub for Mac"
remove_dir "${HOME}/Library/Application Support/com.github.GitHub"
 
echo "*** Removing preferences…"
 
if [ -e "${HOME}/Library/Preferences/com.github.GitHub.plist" ]; then
  cp -f "${HOME}/Library/Preferences/com.github.GitHub.plist" "${HOME}/Library/Preferences/com.github.GitHub.plist_"
fi
 
defaults delete com.github.GitHub
defaults delete com.github.GitHub.LSSharedFileList
 
echo "*** Removing caches…"
 
rm -rf "${HOME}/Library/Caches/GitHub for Mac" "${HOME}/Library/Caches/com.github.Github"
 
echo "*** Stopping and removing Conduit…"
 
launchctl remove com.github.GitHub.Conduit
rm -rf "${HOME}/Library/Containers/com.github.GitHub.Conduit"
 
##echo "*** Removing SSH key…"
 
##find ${HOME}/.ssh -name "*github*_rsa" | while read KEY; do
##  ssh-add -dK "$KEY.pub"
##  mv -f "$KEY" "$KEY.bak"
##  mv -f "$KEY.pub" "$KEY.pub.bak"
##done
 
echo "*** Removing keychain items…"
security -q delete-internet-password -s github.com/mac
security -q delete-generic-password -l 'GitHub for Mac — github.com'
security -q delete-generic-password -l 'GitHub for Mac SSH key passphrase — github.com'
 
echo "*** Removing command line utility…"
 
if [ -e "/usr/local/bin/github" ]; then
  sudo rm -f /usr/local/bin/github
fi
 
if [ -e "/Library/LaunchDaemons/com.github.GitHub.GHInstallCLI.plist" ]; then
  sudo rm -f /Library/LaunchDaemons/com.github.GitHub.GHInstallCLI.plist
fi
 
echo "*** Removing git symlinks…"
 
find /usr/local -lname '*GitHub.app*' -exec sudo rm -f {} \;
