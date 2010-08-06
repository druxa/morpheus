package Morpheus::Bootstrap;
use strict;
use warnings;

use Morpheus::Plugin::Simple;

sub new {

    my $this = {
        priority => 200,
    };

    my $that = Morpheus::Plugin::Simple->new(sub {

        my $loaded = {};
        for my $path (@INC) {
            for my $file (glob "$path/Morpheus/Bootstrap/*.pm") {
                $file =~ m{/([^/]+)\.pm$} or die;
                my $name = $1;
                next if $loaded->{$name};
                require $file;
                my $object = "Morpheus::Bootstrap::$name";
                $object = $object->new() if $object->can('new');
                $loaded->{$name} = {
                    priority => 300,
                    object => $object,
                };
            }
        }

        return {
            "morpheus" => {
                "plugins" => {
    
                    Bootstrap => $this,

                    %$loaded,
                }
            }
        };
    });

    $this->{object} = $that;

    return $that;
}

1;
