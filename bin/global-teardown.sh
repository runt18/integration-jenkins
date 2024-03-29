#!/bin/bash -eu

. /srv/deployment/integration/slave-scripts/bin/global-set-env.sh

# Only delete files, leaving the directory due to a race condition with
# Apache/HHVM threads that might still be running after the job is completed.
# Ends up re creating the directory as owned by www-data which causes
# jenkins-deploy to not be able to tweak the dir on subsequent runs.
# See: T120824

# Have bash '*' to expand dot files as well
shopt -s dotglob
rm -rf "$TMPDIR_FS"/*
rm -rf "$TMPDIR_REGULAR"/*
