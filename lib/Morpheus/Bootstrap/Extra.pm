package Morpheus::Bootstrap::Extra;
use strict;
use warnings;

use Morpheus::Plugin::Env;
#use Morpheus::Plugin::DB;
use Morpheus::Plugin::File;
use Morpheus::Plugin::Core;

use Morpheus::Plugin::Simple;

use Morpheus -defaults => {
    '/morpheus/plugin/file/options/path' => ['./etc/', '/etc/'],
};

sub new {
    return Morpheus::Plugin::Simple->new({
        "morpheus" => {
            "plugins" => {

                Core => {
                    priority => 20,
                    object => Morpheus::Plugin::Core->new(),
                },

                File => {
                    priority => 30,
                    object => Morpheus::Plugin::File->new(),
                },

                Env => {
                    priority => 70,
                    object => Morpheus::Plugin::Env->new(),
                }
            }
        }
    });
}

1;

