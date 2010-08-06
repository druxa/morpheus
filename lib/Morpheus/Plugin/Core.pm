package Morpheus::Plugin::Core;
use strict;

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
