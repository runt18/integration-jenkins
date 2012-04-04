#!/bin/bash -xe
#
# Based on OpenStack project
# https://github.com/openstack/openstack-ci-puppet/blob/master/modules/jenkins_slave/files/slave_scripts/gerrit-git-prep.sh
#


if [ -z "$GERRIT_NEWREV" ] && [ -z "$GERRIT_REFSPEC" ]
then
	echo "This job may only be triggered by Gerrit."
	exit 1
fi

if [ -z "$WORKSPACE" ] || [ -z "$GERRIT_BRANCH" ]; then
	echo "\$WORKSPACE and \$GERRIT_BRANCH must be set."
	exit 1
fi


cd $WORKSPACE || exit 1

git remote update || git remote update # attempt to work around bug #925790
git reset --hard
git clean -x -f -d -q

if [ ! -z "$GERRIT_REFSPEC" ]
then
	git checkout $GERRIT_BRANCH
	git reset --hard remotes/origin/$GERRIT_BRANCH
	git clean -x -f -d -q
	git fetch origin $GERRIT_REFSPEC
	git merge FETCH_HEAD
else
	git checkout $GERRIT_NEWREV
	git reset --hard $GERRIT_NEWREV
	git clean -x -f -d -q
fi
