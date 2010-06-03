package Morpheus::Plugin::File;
use strict;

use base qw(Morpheus::Plugin);

use File::Find;

sub content ($$) {
    my ($self, $ns) = @_;
    my $file = $self->_find_file($ns);
    open my $fh, "<", "$file" or die "open $file failed: $!";
    my $content = do { local $/; <$fh> };
    close $fh or die "close failed: $!";
    return ($file => $content);
}

sub _find_file ($$) {
    my ($self, $ns) = @_;
    my $config = $ns;
    my $file;

    for my $config_path (@{$self->{config_path}}) {
        my @suffix = (qw(.cfg .conf));
        for my $suffix (@suffix) {
            $file = "$config_path/$config$suffix";
            return $file if -e $file;
        }
    }
    return;
}

sub list ($$) {
    my ($self, $main_ns) = @_;

    unless ($self->{config_path}) {
        $self->{config_path} = Morpheus::morph("morpheus/plugin/file/options/path");
        #FIXME: move caching to Morpheus.pm itself
    }

    my %list;
    for my $config_path (@{$self->{config_path}}) {
        $config_path =~ s{/+$}{};
        if (-d "$config_path/$main_ns") {
            find({
                no_chdir => 1,
                follow_skip => 2,
                wanted => sub {
                    -f or return;
                    die unless $File::Find::name =~ m{^\Q$config_path\E/(.*)};
                    my $ns = $1;
                    return unless $ns =~ s{\.(?:cfg|conf)$}{};
                    die "mystery: $ns" unless $self->_find_file($ns);
                    $list{$ns} = 1;
                }
            }, "$config_path/$main_ns");
        }
    }
    my @list = keys %list;

    my $ns = $main_ns;
    while ($ns) {
        push @list, $ns if $self->_find_file($ns);
        $ns =~ s{/?[^/]+$}{};
    }

    return @list;
}

1;
