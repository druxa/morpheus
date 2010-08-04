package Morpheus::Bootstrap;
use strict;
use warnings;

sub list ($) {
    return ("");
}

sub morph ($) {

    our $data;
    return $data if $data;

    my $loaded = {};
    for my $path (@INC) {
        for my $file (glob "$path/Morpheus/Bootstrap/*.pm") {
            $file =~ m{/([^/]+)\.pm$} or die;
            my $booter = $1;
            next if $loaded->{$booter};
            require $file;
            my $object = "Morpheus::Bootstrap::$booter";
            $object = $object->new() if $booter->can('new');
            $loaded->{$booter} = {
                priority => 300,
                object => $object,
            };
        }
    }

    $data = {
        "morpheus" => {
            "plugins" => {

                Bootstrap => {
                    priority => 200,
                    object => 'Morpheus::Bootstrap',
                },

                %$loaded,
            }
        }
    };

    return $data;
}

1;
