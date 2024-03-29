#!/bin/bash
#
# puppet-test-runner - run puppet apply --noop to manifests in 'tests' dirs
#
# Written by Antoine Musso, July 2013
#
#
# Copyright © 2013, Antoine Musso
# Copyright © 2013, Wikimedia Foundation Inc.

# Directory where the puppet modules are located
MODULE_DIR=`pwd`"/modules"

# Maximum number of 'puppet apply --noop' operations to triggers (xargs -P)
MAX_JOBS=4

# puppet_apply_noop ()
# Wrapper around puppet apply noop
# Requires an export of MODULE_DIR that points to the puppet modules directory.
#
# Parameter: path to a puppet manifest
# Returns: exit code of puppet apply
#
puppet_apply_noop() {
	manifest="$1"
	# Might make use of '--verbose --evaltrace'
	puppet apply --noop --modulepath="$MODULE_DIR" $manifest

	test_result=$?
	[[ $test_result == 0 ]] \
		&& echo "SUCCESS: puppet applied '$manifest'" \
		|| echo "ERROR: failed tests for '$manifest'"
	return $test_result
}

echo "INFO: Will assume modules are under '$MODULE_DIR'"
echo "INFO: Triggering tests using up to $MAX_JOBS puppet runners"

# Export environnent so that is made available to the subshell executed
# by xargs.
export MODULE_DIR
export -f puppet_apply_noop

find . -type f -wholename '*tests/*.pp' -print0 \
	| xargs -0 -t -I '{}' -P$MAX_JOBS -n1 bash -c 'puppet_apply_noop {}'
FINAL_EXIT_CODE=$?

echo "INFO: Final exit code: $FINAL_EXIT_CODE"
exit $FINAL_EXIT_CODE
