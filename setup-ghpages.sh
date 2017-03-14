#!/usr/bin/env bash
# DESC: Set up personal GitHub Pages repository for deployment using Hugo.

# Branch containinig source files
GIT_SRC_BRANCH="hugo"
# Branch containinig destination files
GIT_DST_BRANCH="master"
# Git destination directory
GIT_DST_DIR="public"
# GitHub personal repository name
GIT_USERNAME="cgswong"

log() {
  echo -e "\033[1;32m${1}\033[0m"
}

log "Deleting the \`${GIT_DST_BRANCH}\` branch"
git branch -D ${GIT_DST_BRANCH}
git push origin --delete ${GIT_DST_BRANCH}

log "Creating an empty, orphaned \`${GIT_DST_BRANCH}\` branch"
git checkout --orphan ${GIT_DST_BRANCH}
git rm --cached $(git ls-files)

log "Grabbing one file from the \`${GIT_SRC_BRANCH}\` branch so that a commit can be made"
git checkout "${GIT_SRC_BRANCH}" README.md
git commit -m "Initial commit on ${GIT_DST_BRANCH} branch"
git push origin ${GIT_DST_BRANCH}

log "Returning to the \`${GIT_SRC_BRANCH}\` branch"
git checkout -f "${GIT_SRC_BRANCH}"

log "Removing the \`${GIT_DST_DIR}\` folder to make room for the \`${GIT_DST_BRANCH}\` subtree"
rm -rf ${GIT_DST_DIR}
git add -u
git commit -m "Remove stale ${GIT_DST_DIR} folder"

log "Adding the new \`${GIT_DST_BRANCH}\` branch as a subtree"
git subtree add --prefix=${GIT_DST_DIR} git@github.com:${GIT_USERNAME}/${GIT_USERNAME}.github.io.git ${GIT_DST_BRANCH} --squash

log "Pulling down the just committed file to help avoid merge conflicts"
git subtree pull --prefix=${GIT_DST_DIR} git@github.com:${GIT_USERNAME}/${GIT_USERNAME}.github.io.git ${GIT_DST_BRANCH}
