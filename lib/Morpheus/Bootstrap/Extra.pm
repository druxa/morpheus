package Morpheus::Bootstrap::Extra;
use strict;
use warnings;

# ABSTRACT: extra plugins - Env and File

use Morpheus::Plugin::Env;
use Morpheus::Plugin::File;

use Morpheus::Plugin::Simple;

use Morpheus -defaults => {
    '/morpheus/plugin/file/options/path' => ['./etc/', '/etc/'],
};

sub new {
    return Morpheus::Plugin::Simple->new({
        "morpheus" => {
            "plugins" => {

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

