package Morpheus::Plugin::Env;
use strict;

use base qw(Morpheus::Plugin);

sub list ($$) {
    my ($class, $ns) = @_;
    return ("");
}

sub content ($$) {
    my ($self, $ns) = @_;
    die if $ns;
    return ("MORPHEUS" => $ENV{MORPHEUS}) if $ENV{MORPHEUS};
    return;
}

1;
