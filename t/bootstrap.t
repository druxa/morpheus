#!/usr/bin/perl
package Morpheus::Test::Bootstrap;

use strict;
use warnings;

use base qw(Test::Class);
use Test::More;
use Symbol;

$ENV{PERL5LIB} = 'lib';

sub xqx {
    my $cmd = shift;
    my $res = scalar(`$cmd`);
    die "$cmd failed: $?" if $?;
    return $res;
}

sub general : Test(4) {
    is(xqx(q#perl -e 'use Morpheus -defaults => { test_bootstrap => 1 }; print morph("test_bootstrap")'#), 1, "Deafults plugin loads");
    is(xqx(q#perl -e 'use Morpheus -overrides => { test_bootstrap => 2 }; print morph("test_bootstrap")'#), 2, "Overrides plugin loads");
    is(xqx(q#MORPHEUS='test_bootstrap => 4' perl -e 'use Morpheus -defaults => { test_bootstrap => 3 }; print morph("test_bootstrap")'#), 4, 
        "Env plugin loads");
    is(xqx(q#MORPHEUS='test_bootstrap => 4' perl -It/lib -e 'use Morpheus -defaults => { test_bootstrap => 3 }; print morph("test_bootstrap")'#), 3, 
        "Env plugin disabled by a specific bootstrapper");
}

__PACKAGE__->runtests;
