package Morpheus::Bootstrap::Vital;
use strict;
use warnings;

# ABSTRACT: bootstrap enabling Overrides and Defaults functionality

use Morpheus::Overrides;
use Morpheus::Defaults;

use Morpheus::Plugin::Simple;

sub new {
    return Morpheus::Plugin::Simple->new({
        "morpheus" => {
            "plugins" => {

                Overrides => {
                    priority => 100,
                    object => 'Morpheus::Overrides',
                },
                Defaults => {
                    priority => 10,
                    object => 'Morpheus::Defaults',
                },
            }
        }
    });
}

1;

