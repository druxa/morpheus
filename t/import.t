#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 7;
use Test::Exception;

use lib 'lib';
use Morpheus -defaults => {
    "test/import/collision" => do { 
        no strict; 
        package Defaults; 
        @x = (1, 2); %x = (a => "b");
        @y = (1,2,3); $y = "a";
        { x => \*x, y => \*y}
    },
};

is_deeply(scalar(eval(q#package X; use Morpheus "test/import/collision" => [qw(@x)]; [@x]#)), [1,2], "@/% collision => @");
is_deeply(scalar(eval(q#package X; use Morpheus "test/import/collision" => [qw(%x)]; return {%x}#)), {a=>"b"}, "@/% collision => %");
throws_ok(sub{ eval(q#package X; use Morpheus "test/import/collision" => [qw($x)];#); die if $@}, qr/not defined/, "@/% collition => \$");

is_deeply(scalar(eval(q#package X; use Morpheus "test/import/collision" => [qw(@y)]; [@y]#)), [1,2,3], "@/\$ collision => @");
is(scalar(eval(q#package X; use Morpheus "test/import/collision" => [qw($y)]; $y#)), "a", "@/\$ collision => \$");
throws_ok(sub{ eval(q#package X; use Morpheus "test/import/collision" => [qw(%y)];#); die if $@}, qr/not defined/, "@/\$ collision => %");

is(scalar(eval(q#package X; my $y; use Morpheus "test/import/collision/y" => \$y; $y#)), "a", "binding to 'my'");
