#!/usr/bin/perl

use strict;
use warnings;

use IO::All;
use Test::More tests => 22;
use Test::Exception;

use lib 'lib';

BEGIN {
    $ENV{YANDEX_SANDBOX_DB} = 'morpheus';
}
use Yandex::DB;
use Yandex::DB::Plugin::Sandbox;
use Morpheus -overrides => {
    "morpheus/plugin/db/options" => { connect => sub { return getdb("morpheus") } },
};

getdb("morpheus")->do(q{create table Morpheus (Name varchar(255) primary key, Config blob)});

# --- sql specific ---

getdb("morpheus")->do(q{insert Morpheus set Name = ?, Config = ?}, undef, "test/spec_symbols/x1", '1');
getdb("morpheus")->do(q{insert Morpheus set Name = ?, Config = ?}, undef, "test/spec-symbols/x2", '2');
getdb("morpheus")->do(q{insert Morpheus set Name = ?, Config = ?}, undef, "test/spec%symbols/x3", '3');
getdb("morpheus")->do(q{insert Morpheus set Name = ?, Config = ?}, undef, "test/spec\\tsymbols/x4", '4');

is_deeply(morph("test/spec_symbols"), {x1 => 1}, "DB: spec symbols '_'");
is_deeply(morph("test/spec%symbols"), {x3 => 3}, "DB: spec symbols '%'");
is_deeply(morph("test/spec\\tsymbols"), {x4 => 4}, "DB: spec symbols '\\'");

# --- generic tests ---
use File::Find;
find({ 
    no_chdir => 1,
    follow_skip => 2,
    wanted => sub {
        -f or return;
        die unless $File::Find::name =~ m{^t/etc/test/file/(.*)\.cfg};
        my $name = "test/db/$1";
        my $content = ${io($File::Find::name)};
        $content =~ s{test/file/}{test/db/}g;
        getdb("morpheus")->do(q{insert Morpheus set Name = ?, Config = ?}, undef, $name, $content);
    }, 
}, 't/etc/test/file/');

is(morph("test/db/stash/scalar"), 1, "DB: scalars from stash");
is_deeply(morph("test/db/stash/array", '@'), [1,2], "DB: arrays from stash");
is_deeply(morph("test/db/stash/hash", '%'), {1=>2,3=>4}, "DB: hashes from stash");

is(morph("test/db/stash/normalize/x/y"), 1, "DB: normalize stash");

is_deeply(morph("test/db/returned/complex"), {1 => [2]}, "DB: a complex returned value");
is(morph("test/db/returned/normalize/a/b/c"), 1, "DB: normalize returned value");

is(morph("test/db/stash/returned"), undef, "DB: returned value is ignored if stash is not empty");

is(morph("test/db/stash/override/file/explicit"), 2, "DB: nested file overrides explicitly");
is(morph("test/db/stash/override/file/implicit"), 2, "DB: nested file overrides implicitly");

is(morph("test/db/stash/slave"), 2, "DB: resursive dependencies are resolved");
is(morph("test/db/stash/super"), 2, "DB: previous value is accessible within a nested file overriding");

is(morph("test/db")->{stash}->{scalar}, 1, "DB: lower configs found");
is(morph("test/db/stash/hash/1"), 2, "DB: higher configs found");

is_deeply(scalar(eval(q#package X; use Morpheus "test/db/collision" => [qw(@x)]; [@x]#)), [1,2], "@/% collision => @");
is_deeply(scalar(eval(q#package X; use Morpheus "test/db/collision" => [qw(%x)]; return {%x}#)), {a=>"b"}, "@/% collision => %");
throws_ok(sub{ eval(q#package X; use Morpheus "test/db/collision" => [qw($x)];#); die if $@}, qr/not defined/, "@/% collition => \$");

is_deeply(scalar(eval(q#package X; use Morpheus "test/db/collision" => [qw(@y)]; [@y]#)), [1,2,3], "@/\$ collision => @");
is(scalar(eval(q#package X; use Morpheus "test/db/collision" => [qw($y)]; $y#)), "a", "@/\$ collision => \$");
throws_ok(sub{ eval(q#package X; use Morpheus "test/db/collision" => [qw(%y)];#); die if $@}, qr/not defined/, "@/\$ collision => %");

