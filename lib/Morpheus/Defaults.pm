package Morpheus::Defaults;
use strict;
use base qw(Morpheus::Overrides);

sub cache {
    our $cache;
    return \$cache;
}

1;
