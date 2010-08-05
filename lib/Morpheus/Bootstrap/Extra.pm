package Morpheus::Bootstrap::Extra;
use strict;
use warnings;

use Morpheus::Plugin::Env;
use Morpheus::Plugin::DB;
use Morpheus::Plugin::File::Path;
use Morpheus::Plugin::File;
use Morpheus::Plugin::Core;

sub list ($) {
    return ("" => "");
}

sub get ($) {

    our $data = {
        "morpheus" => {
            "plugins" => {

                Core => {
                    priority => 20,
                    object => 'Morpheus::Plugin::Core',
                },

                File => {
                    priority => 30,
                    object => Morpheus::Plugin::File->new(),
                },
                FilePath => { #TODO: drop this plugin and configure Env plugin instead
                    priority => 40,
                    object => 'Morpheus::Plugin::File::Path',
                },

                DB => {
                    priority => 50,
                    object => Morpheus::Plugin::DB->new(),
                },

                Env => {
                    priority => 70,
                    object => Morpheus::Plugin::Env->new(),
                }
            }
        }
    } unless $data;

    return $data;
}

1;

