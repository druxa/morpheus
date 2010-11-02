package Morpheus::Plugin::Core;
use strict;

# ABSTRACT: plugin providing some core constants

use Sys::Hostname::Long;

use Morpheus::Plugin::Simple;

sub new {
    return Morpheus::Plugin::Simple->new(sub {
        return {
            'system' => {
                hostname => hostname_long(),
                script => $0,
            }
        };
    });
}

1;
