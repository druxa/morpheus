package Morpheus::Plugin::Env;
use strict;

sub list ($$) {
    my ($class, $ns) = @_;
    return ("");
}

sub morph ($$) {
    my ($class, $ns) = @_;
    return undef unless $ns eq "";

    our $data;
    unless (defined $data) {
        $data = {};
        if (defined $ENV{MORPHEUS}) {
            my @data = eval "package Morpheus::Plugin::Env::Sandbox; $ENV{MORPHEUS}";
            die $@ if $@;
            if (@data == 1) {
               ($data) = @data;
            } else {
                $data = {@data};
            }
        }
    }

    return $data;
}

1;
