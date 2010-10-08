package Morpheus::Plugin::Env;
use strict;

# ABSTRACT: plugin which provides config values based on MORPHEUS env variable

use base qw(Morpheus::Plugin::Content);

sub list ($$) {
    my ($class, $ns) = @_;
    return ('' => 'MORPHEUS'); #TODO: configure like (ENV_VAR1 => '/key1/', ENV_VAR2 => '/key2/subkey/', ...)
}

sub content ($$) {
    my ($self, $token) = @_;
    die if $token ne 'MORPHEUS';
    return $ENV{MORPHEUS} if $ENV{MORPHEUS};
    return;
}

1;
