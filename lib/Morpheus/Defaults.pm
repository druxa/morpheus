package Morpheus::Defaults;
use strict;

# ABSTRACT: plugin for defining configuration from perl code

use base qw(Morpheus::Overrides);

our $cache = {};
sub cache {
    return $cache;
}

1;
