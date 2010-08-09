package Morpheus::Plugin::File;
use strict;

use base qw(Morpheus::Plugin::Content);

use File::Find;

sub content ($$) {
    my ($self, $file) = @_;
    open my $fh, "<", "$file" or die "open '$file' failed: $!";
    my $content = do { local $/; <$fh> };
    close $fh or die "close '$file' failed: $!";
    return $content;
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
    $main_ns =~ s{^/+}{};

    unless ($self->{config_path}) {
        $self->{config_path} = Morpheus::morph("/morpheus/plugin/file/options/path");
        #FIXME: move these options to new() parameters to allow several File plugins coexist and be configured differently
    }

    return () unless $self->{config_path};

    my @list;
    for my $config_path (@{$self->{config_path}}) {
        $config_path =~ s{/+$}{};
        my %list;

        my $process_file = sub ($;$) {
            my ($full_file, $ns) = @_;
            -f $full_file or return;
            die 'mystery' unless $full_file =~ m{^\Q$config_path\E/(.*)};
            my $file = $1;
            return unless $file =~ s{(?:\.(-?\d+))?\.(?:cfg|conf)$}{}; #TODO: make the list of suffixes configurable
            return if $ns and $file ne $ns;
            push @{$list{$file}}, {
                file => $full_file,
                priority => $1 || 0,
            };
        };

        if (-d "$config_path/$main_ns") {
            find({
                no_chdir => 1,
                follow_skip => 2,
                wanted => sub { $process_file->($File::Find::name) },
            }, "$config_path/$main_ns");
        }

        my $ns = $main_ns;
        while ($ns) {
            for my $file (glob ("$config_path/$ns*")) { # $ns.cfg or $ns.10.cfg but not $ns-blah.cfg
                $process_file->($file, $ns);
            }
            $ns =~ s{/?[^/]+$}{};
        }

        for my $ns (sort { length $b <=> length $a } keys %list) {
            for (sort { $b->{priority} <=> $a->{priority} } @{$list{$ns}}) {
                push @list, $ns => $_->{file};
            }
        }
    }

    return @list; 
    # priority rules: config path, then file depth, then file suffix.
    # for example if config path is /etc/:/etc2/ and there exist files 
    # /etc/x/y.10.cfg /etc/x/y.cfg /etc/x/y.-10.cfg 
    # /etc/x.10.cfg /etc/x.cfg /etc/x.-10.cfg 
    # /etc2/x/y.10.cfg /etc2/x/y.cfg /etc2/x/y.-10.cfg 
    # /etc2/x.10.cfg /etc2/x.cfg /etc2/x.-10.cfg
    # then the order of their priority from higher to lower is from left to right
}

1;
