package Morpheus::Bootstrap::PPB;
use strict;
use warnings;

use Morpheus::Plugin::DB;
use Morpheus::Plugin::File;

use Morpheus::Plugin::Simple;

sub new {
    return Morpheus::Plugin::Simple->new({
        "morpheus" => {
            "plugins" => {

                PPB => { priority => 400 }, # boost myself

                FilePath => {
                    priority => 40,
                    object => Morpheus::Plugin::Simple->new({
                        "morpheus/plugin/file/options/path" => sub {
                            my $path = "./etc:/etc";
                            $path = "$ENV{CONFIG_PATH}:$path" if $ENV{CONFIG_PATH};
                            my @path = grep {$_} split /[:\s]+/, $path;
                            return [@path];
                        }->(),
                    }, 1),
                },

                DB => {
                    priority => 50,
                    object => Morpheus::Plugin::DB->new({
#                        db => sub { require Yandex::DB; getdb("meta"); },
                    }),
                },
            }
        }
    });
}

1;

