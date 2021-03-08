# SUSE's openQA tests
#
# Copyright © 2021 Guillaume GARDET
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: glibc
# Summary: Check GLIBC_TUNABLES support
# Maintainer: Guillaume GARDET <guillaume@opensuse.org>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    select_console 'root-console';

    if (check_var('ARCH', 'aarch64') && check_var('AARCH64_MTE_SUPPORTED', '1')) {
        record_info('Testing MTE on aarch64');
        zypper_call 'in gcc';

        select_console 'user-console';
        assert_script_run('curl ' . data_url("data/console/mte_test.c") . ' -o mte_test');

        assert_script_run 'gcc -Wall mte_test.c -o mte_test';

        record_info('Default', 'MTE should be disabled by default');
        asser_script_run('./mte_test');

        record_info('Async', 'MTE Async mode');
        assert_script_run('export GLIBC_TUNABLES="glibc.mem.tagging=1"');
        if (script_run('./mte_test') == 0) {
            # This run should seg fault
            return 1;
        }

        record_info('Sync', 'MTE Sync mode');
        assert_script_run('export GLIBC_TUNABLES="glibc.mem.tagging=3"');
        if (script_run('./mte_test') == 0) {
            # This run should seg fault
            return 1;
        }

        record_info('Disabled', 'MTE disabled');
        assert_script_run('export GLIBC_TUNABLES="glibc.mem.tagging=0"');
        asser_script_run('./mte_test');

        assert_script_run('export GLIBC_TUNABLES=""');
    }
    else {
        record_info('No GLIBC_TUNABLES', 'No GLIBC_TUNABLES available for testing on this worker');
    }
}

1;
