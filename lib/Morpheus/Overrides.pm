package Morpheus::Overrides;
use strict;
use Morpheus -export => [qw(merge)];

sub cache {
    our $cache;
    return \$cache;
}

sub import ($$) {
    my ($class, $patch) = @_;
    return unless $patch;
    die "unexpeced $patch" unless ref $patch eq "HASH";

    merge(${$class->cache}, $patch);
}

sub list ($$) {
    return ("");
}

sub morph ($$) {
    my ($class, $ns) = @_;
    return if $ns;
    return ${$class->cache};
}

1;
