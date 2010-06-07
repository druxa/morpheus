package Morpheus::Defaults;
use strict;
use base qw(Morpheus::Overrides);

our $cache = {};
sub cache {
    return $cache;
}

1;
