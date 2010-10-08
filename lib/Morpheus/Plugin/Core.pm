package Morpheus::Plugin::Core;
use strict;

# ABSTRACT: plugin providing some core constants

use Sys::Hostname;

use Morpheus::Plugin::Simple;

sub new {
    return Morpheus::Plugin::Simple->new(sub {
        return {
            'system' => {
                hostname => hostname(),
                script => $0,
            }
        };
    });
}

1;
