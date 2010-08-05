package Morpheus::Bootstrap::_Extra;
use strict;
use warnings;

sub list ($) {
    return ("" => "");
}

sub get ($) {

    our $data = {
        "morpheus" => {
            "plugins" => {

                Extra => {
                    priority => 0,
                    object => 0,
                },
            }
        }
    } unless $data;
    return $data;
}

1;

