#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 20;
use Test::Exception;

use lib 'lib';

use Morpheus -overrides => {
    "morpheus/plugin/file/options" => { path => ["t/etc2/", "t/etc",] },
};

is(morph("test/file/stash/scalar"), 1, "File: scalars from stash");
is_deeply(morph("test/file/stash/array"), [1,2], "File: arrays from stash");
is_deeply(morph("test/file/stash/hash"), {1=>2,3=>4}, "File: hashes from stash");

is(morph("test/file/stash/normalize/x/y"), 1, "File: normalize stash");

is_deeply(morph("test/file/returned/complex"), {1 => [2]}, "File: a complex returned value");
is(morph("test/file/returned/normalize/a/b/c"), 1, "File: normalize returned value");

is(morph("test/file/stash/returned"), undef, "File: returned value is ignored if stash is not empty");

is(morph("test/file/stash/override/file/explicit"), 2, "File: nested file overrides explicitly");
is(morph("test/file/stash/override/file/implicit"), 2, "File: nested file overrides implicitly");
is(morph("test/file/stash/override/path"), 2, "File: earlier path overrides");

is(morph("test/file/stash/slave"), 2, "File: resursive dependencies are resolved");
is(morph("test/file/stash/super"), 2, "File: previous value is accessible within a nested file overriding");

is(morph("test/file")->{stash}->{scalar}, 1, "File: lower config files found");
is(morph("test/file/stash/hash/1"), 2, "File: higher config files found");

is_deeply(scalar(eval(q#package X; use Morpheus "test/file/collision" => [qw(@x)]; [@x]#)), [1,2], "@/% collision => @");
is_deeply(scalar(eval(q#package X; use Morpheus "test/file/collision" => [qw(%x)]; return {%x}#)), {a=>"b"}, "@/% collision => %");
throws_ok(sub{ eval(q#package X; use Morpheus "test/file/collision" => [qw($x)];#); die if $@}, qr/not defined/, "@/% collition => \$");

is_deeply(scalar(eval(q#package X; use Morpheus "test/file/collision" => [qw(@y)]; [@y]#)), [1,2,3], "@/\$ collision => @");
is(scalar(eval(q#package X; use Morpheus "test/file/collision" => [qw($y)]; $y#)), "a", "@/\$ collision => \$");
throws_ok(sub{ eval(q#package X; use Morpheus "test/file/collision" => [qw(%y)];#); die if $@}, qr/not defined/, "@/\$ collision => %");



