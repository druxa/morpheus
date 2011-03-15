#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 3;

use lib 'lib';
$ENV{PERL5LIB} = 'lib';

$ENV{MORPHEUS} = q@
    '/foo/bar' => 5,
    '/x' => { 'y' => 6, 'z' => { t => 7 } },
@;

my $result;

$result = qx(bin/morph /foo);
is(
    $result,
'{
   "bar" : 5
}
',
    'morph without arguments prints json'
);

$result = qx(bin/morph /foo/bar);
is(
    $result,
    "5\n",
    'morph without arguments prints json'
);

$result = qx(bin/morph --format=dumper /foo);
is(
    $result,
"{
  'bar' => 5
}
",
    'morph with dumper format'
);

# TODO - test xml and tt2 formats
