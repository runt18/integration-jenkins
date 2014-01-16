#!/bin/bash -xe
#
# Script to push VisualEditor updates to mediawiki/extensions.git

MWEXT_DIR='src/extensions'
GERRIT_USER='jenkins-bot'
MWEXT_REPO_SSH="ssh://${GERRIT_USER}@gerrit.wikimedia.org:29418/mediawiki/extensions.git"

if [[ "$USER" != "jenkins" ]]; then
	echo "Must be run as 'jenkins' user to access $GERRIT_USER SSH credentials"
	exit 1
fi

cd "${MWEXT_DIR}"
git show

# Steps below needs the jenkins-bot credentials and should not write on disk
# since files in the workspace belong to jenkins-slave user.
git push "$MWEXT_REPO_SSH" HEAD:refs/for/master
MWEXT_HEAD=`git rev-parse HEAD`
ssh -p 29418 "${GERRIT_USER}"@gerrit.wikimedia.org "gerrit approve --code-review +2 --verified +2 --submit $MWEXT_HEAD"