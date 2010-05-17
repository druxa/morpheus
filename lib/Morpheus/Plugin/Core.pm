package Morpheus::Plugin::Core;
use strict;

use Sys::Hostname;

sub list {
    return ("");
}

sub morph ($$) {
    my ($class, $ns) = @_;
    return (undef) if $ns;

    our $data;
    $data = {
        'system' => {
            hostname => hostname(),
            script => $0,
        }
    } unless defined $data;

    return $data;
}

1;
