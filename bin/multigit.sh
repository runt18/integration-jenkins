#!/bin/bash -e

#
# multigit.sh
#
# Utility to fetch multiple git repositories and apply a patchset to the proper
# git repository.  This is meant to be used when several projects are sharing a
# common Jenkins job. ZUUL_PROJECT would let us detect which project triggered
# the change and apply the patchset to the proper git repository.
#
# example:
#
#  multigit.sh mediawiki/services/parsoid mediawiki/services/parsoid/deploy
#  multigit.sh mediawiki/core mediawiki/extensions/Echo
#
# Final destinations will be prefixed with $BASE_DIR (default: $WORKSPACE)
#
# Adapted for Wikimedia from openstack-infra/devstack-gate project
#
# Copyright (C) 2011-2013 OpenStack LLC.
# Copyright (C) 2013 Antoine "hashar" Musso
# Copyright (C) 2013 Wikimedia Foundation Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
#
# See the License for the specific language governing permissions and
# limitations under the License.

# URL to fetch ZUUL references from.
if [ -z "$ZUUL_URL" ]; then
	echo "\$ZUUL_URL is not set. Aborting."
	exit 1
fi

# URL to fetch from Gerrit (reference repository)
GERRIT_URL="https://gerrit.wikimedia.org/r/p"

# Url to the Gerrit change
GERRIT_CHANGE="https://gerrit.wikimedia.org/r/#/c/$ZUUL_CHANGE/$ZUUL_PATCHSET"

# Base path for locally replicated repositories.
GERRIT_REFERENCE=${GERRIT_REFERENCE:-/srv/ssd/gerrit}

# Prefix where to clone repositories too
BASE_DIR=${BASE_DIR:-$WORKSPACE}

echo "Change triggered by $GERRIT_CHANGE"
echo
echo "Triggering informations:"
echo "Zuul URL : $ZUUL_URL"
echo "Pipeline : $ZUUL_PIPELINE"
echo "Project  : $ZUUL_PROJECT"
echo "Branch   : $ZUUL_BRANCH"
echo
echo "Hostname : `hostname -f`"
echo

PROJECTS=$@

function clone_project {
	local project=$1

	# Find out destination

	# Specificied using: <project>:<destination>
	if [[ "$project" =~ (.*):(.*) ]]; then
		project=${BASH_REMATCH[1]}
		dest=${BASH_REMATCH[2]}

	# Unless specificed, always get mediawiki/core directly in the workspace
	elif [ "$project" == 'mediawiki/core' ]; then
		dest=""

	# Shortcut for mediawiki extensions
	elif [[ "$project" =~ mediawiki/(extensions/.*) ]]; then
		dest=${BASH_REMATCH[1]}

	# Fallback to usual git behavior
	else
		dest=`basename $project`
	fi

	dest="$BASE_DIR/$dest"

	# Clone or refresh repository

	# Fetch from the locally replicated Gerrit repository if it exist or simply
	# fallback to Gerrit.
	ref_repo="$GERRIT_REFERENCE/${project}.git"
	if [[ ! -d "$ref_repo" ]]; then
		ref_repo="$GERRIT_URL/$project"
	fi

	# Variable used for display purposes
	action_done="cloning"
	if [[ -d "$dest/.git" ]]; then
		echo "Refreshing $project in $dest"
		action_done="refreshing"
		cd "$dest"
		git remote set-url origin "$ref_repo"
		git fetch origin
	else
		if [[ ! -d "$dest" ]]; then
			echo "Cloning $project in $dest"
			git clone "$ref_repo" "$dest"
		else
			# Workaround cloning in $WORKSPACE
			# Git refuses to clone at an existing directory
			echo "Initing $project in already existing $dest"
			action_done="initing"
			cd "$dest"
			git init .
			git remote add origin "$ref_repo"
			git fetch origin
		fi
	fi

	# Apply patch to relevant working directory or match the change branch if
	# available.
	cd "$dest"
	echo "Now in directory $dest"
	if [ "$project" == "$ZUUL_PROJECT" ]; then
		echo "Applying patch $ZUUL_REF to $project in $dest"
		action_done="$action_done and patching"
		git_fetch_at_ref $project $ZUUL_REF
		git_checkout FETCH_HEAD
	else
		echo "Attempting to get $project to match change branch '$ZUUL_BRANCH'"
		if git_has_branch $project $ZUUL_BRANCH; then
			echo "Switching $project to $ZUUL_BRANCH"
			git_checkout $ZUUL_BRANCH
		else
			echo "Checking out $projet to 'master'"
			git_checkout 'master'
		fi
	fi

	if [ "$project" == "mediawiki/core" ]; then
		echo "Skipping submodules for mediawiki/core"
		echo "... wmf branches have too many extensions"
	else
		echo "Refreshing $project submodules..."
		git submodule update --init --recursive
	fi

	echo -e "Done $action_done $project\n"
	cd $WORKSPACE
}

# Copy pasted from OpenStack devstack-gate
function git_fetch_at_ref {
	local project=$1
	local ref=$2
	if [ "$ref" != "" ]; then
		git fetch $ZUUL_URL/$project $ref
		return $?
	else
		# failure
		return 1
	fi
}

# Copy pasted from OpenStack devstack-gate
function git_has_branch {
	local project=$1
	local branch=$2

	if git branch -a|grep remotes/origin/$branch>/dev/null; then
		return 0
	else
		return 1
	fi
}

# Copy pasted from OpenStack devstack-gate
function git_checkout {
	local branch=$1
	local reset_branch=$branch

	if [[ "$branch" != "FETCH_HEAD" ]]; then
		reset_branch="remotes/origin/$branch"
	fi
	set -x
	git checkout -f $branch
	git reset --hard $reset_branch
	git clean -xdff -q
	set +x
}

for project in $PROJECTS; do
	clone_project $project
done
