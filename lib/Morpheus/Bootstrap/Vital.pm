package Morpheus::Bootstrap::Vital;
use strict;
use warnings;

use Morpheus::Overrides;
use Morpheus::Defaults;

sub list ($) {
    return ("" => "");
}

sub get ($) {

    our $data = {
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
    } unless $data;
    return $data;
}

1;

