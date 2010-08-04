package Morpheus::Bootstrap::UnExtra;
use strict;
use warnings;

sub list ($) {
    return ("");
}

sub morph ($) {

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

