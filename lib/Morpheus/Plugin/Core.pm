package Morpheus::Plugin::Core;
use strict;

use Sys::Hostname;

sub list {
    return ('' => '');
}

sub get ($$) {
    my ($class, $token) = @_;
    die 'mystery' if $token;

    our $data = {
        'system' => {
            hostname => hostname(),
            script => $0,
        }
    } unless defined $data;

    return $data;
}

1;
