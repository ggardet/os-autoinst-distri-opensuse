# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: bind upstream testsuite
#          prepare, build, fix broken tests and execute testsuite
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base 'consoletest';
use testapi;
use strict;
use utils 'zypper_call';
use version_utils 'is_sle';
use serial_terminal 'select_virtio_console';

sub run {
    select_virtio_console();

    # script to add missing dependency repos and in second run remove only added products/repos
    assert_script_run 'curl -v -o /tmp/script.sh ' . data_url('qam/handle_bind_source_dependencies.sh');
    assert_script_run 'bash /tmp/script.sh';
    if (is_sle('<=12-SP3')) {
        # preinstall libmysqlclient-devel because on 12* are multiple versions and zypper can't decide, perl-IO-Socket-INET6 for reclimit test
        zypper_call 'in libmysqlclient-devel bind rpm-build perl-IO-Socket-INET6';
    }
    elsif (is_sle('>=15')) {
        # bind-utils for dig, net-tools-deprecated for ifconfig, perl-IO-Socket-INET6 for reclimit, perl-Net-DNS for xfer, dnspython for chain test
        zypper_call 'in bind rpm-build bind-utils net-tools-deprecated perl-IO-Socket-INET6 perl-Socket6 perl-Net-DNS python3-dnspython';
    }
    # install bind sources to build and run testsuite
    zypper_call 'si bind';
    assert_script_run 'rpm -q bind';
    assert_script_run 'cd /usr/src/packages';
    # build the bind package with tests
    assert_script_run 'rpmbuild -bc SPECS/bind.spec', 500;
    assert_script_run 'cd /usr/src/packages/BUILD/bind-*/bin/tests/system && pwd';
    # replace build bind binaries with system bind binaries
    assert_script_run 'sed -i \'s/$TOP\/bin\/check\/named-checkconf/\/usr\/sbin\/named-checkconf/\' conf.sh';
    assert_script_run 'sed -i \'s/$TOP\/bin\/check\/named-checkzone/\/usr\/sbin\/named-checkzone/\' conf.sh';
    assert_script_run 'sed -i \'s/$TOP\/bin\/named\/named/\/usr\/sbin\/named/\' conf.sh';
    assert_script_run 'sed -i \'s/$TOP\/bin\/dig\/dig/\/usr\/bin\/dig/\' conf.sh';
    upload_logs 'conf.sh';
    # add missing $ and replace $dig with exported $DIG
    assert_script_run 'sed -i \'s/^DIG/$DIG/\' nsupdate/tests.sh' if is_sle('<=12-SP3');
    assert_script_run 'sed -i \'s/$dig/$DIG/\' nsupdate/tests.sh' if is_sle('<=12-SP3');
    # no idea what is with rpz on SLE 12 SP3, remove it for now
    assert_script_run 'rm -rf rpz' if is_sle('<=12-SP3');
    # fix permissions and executables to run the testsuite
    assert_script_run 'chown root:root -R .';
    assert_script_run 'chmod +x *.sh *.pl';
    # setup loopback interfaces for testsuite
    assert_script_run 'sh ifconfig.sh up';
    assert_script_run 'ip a';
    my $timeout = is_sle('<=12-SP3') ? 1500 : 2500;
    assert_script_run 'sh runall.sh', $timeout;
    # remove loopback interfaces
    assert_script_run 'sh ifconfig.sh down';
    assert_script_run 'ip a';
}

sub post_run_hook {
    # deregister products or repositories added with first script run
    assert_script_run 'bash /tmp/script.sh';
}

sub post_fail_hook {
    # print out what tests failed
    assert_script_run 'egrep "^A|^R" systests.output|grep -B1 FAIL';
}

1;
