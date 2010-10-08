package Morpheus::Bootstrap;
use strict;
use warnings;

# ABSTRACT: initial morpheus plugin which loads all other plugins

use Morpheus::Plugin::Simple;

our $BOOTSTRAP_PATH;
$BOOTSTRAP_PATH = [@INC];
@$BOOTSTRAP_PATH = split /[\s:]+/, $ENV{MORPHEUS_BOOTSTRAP_PATH} if defined $ENV{MORPHEUS_BOOTSTRAP_PATH};

sub import {
    my $class = shift;
    while (@_) {
        my $cmd = shift;
        if ($cmd eq '-path') {
            push @$BOOTSTRAP_PATH, @{(shift)};
        } else {
            die "unexpected option '$cmd'";
        }
    }
}

sub new {

    my $this = {
        priority => 200,
    };

    my $that = Morpheus::Plugin::Simple->new(sub {

        my $loaded = {};

        for my $path (@$BOOTSTRAP_PATH) {
            for my $file (glob "$path/Morpheus/Bootstrap/*.pm") {
                $file =~ m{/([^/]+)\.pm$} or die;
                my $name = "Bootstrap::$1";
                next if $loaded->{$name};
                require $file;
                my $object = "Morpheus::$name";
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

    $this->{object} = $that; #FIXME: weaken?

    return $that;
}

1;
