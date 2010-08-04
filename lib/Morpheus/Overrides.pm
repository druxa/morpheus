package Morpheus::Overrides;
use strict;
use Morpheus -export => [qw(merge normalize)];

our $cache = {};
sub cache {
    return $cache;
}

sub import ($$) {
    my ($class, $patch) = @_;
    return unless $patch;
    die "unexpected $patch" unless ref $patch eq "HASH";
    my $cache = $class->cache();
    push @{$cache->{list}}, $patch;
}

sub list ($$) {
    return ("");
}

sub morph ($$) {
    my ($class, $ns) = @_;
    die "mystery" if $ns;

    my $cache = $class->cache();
    while($cache->{list} and @{$cache->{list}}) {
        my $patch = shift @{$cache->{list}};
        normalize($patch);
        merge($cache->{data}, $patch);
    }
    return $cache->{data};
}

1;
