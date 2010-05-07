package Morpheus;
use strict;
sub normalize ($);
sub merge ($$);
sub morph (;$);
sub export ($$;$);

use Data::Dumper;


#
# use Morpheus -defaults => {
#   "foo.bar" => { x => 1, y => 2 },
#   "bar.baz" => "abc",
# }, -overrides => {
#   "baz.foo" => { "x.y" => 3 },
# }, "x.y.z" => [
#   qw($V1 $V2 @V3 %V4),
#   "v5" => "$V5", "v6.a" => "$A", "v6.b" => "$B",
#   "v7" => [ "$C", "$D", "e" => "@E" ],
# ], -export => [
#   qw(morph normalize merge)
# ];
#
#
#

sub import ($;@) {
    my $class = shift;
    my ($caller) = caller;
    my $export;
    while (@_) {
        my $key = shift;
        my $value = shift;
        if ($key eq "-defaults") {
            Morpheus::Defaults->import($value);
        } elsif ($key eq "-overrides") {
            Morpheus::Overrides->import($value);
        } elsif ($key eq "-export") {
            $export = $value;
        } elsif ($key =~ /^-/) {
            die "unknown option '$key'";
        } else {
            export($caller, $value, $key);
        }
    }
    $export ||= [qw(morph)];
    no strict 'refs';
    *{"${caller}::$_"} = \&{$_} for @$export; # normalize merge morph
}

use Morpheus::Overrides;
use Morpheus::Defaults;
use Morpheus::Plugin::Core;
use Morpheus::Plugin::Env;

use Morpheus::Plugin::File;

#use Morpheus::Plugins::DB;

 
sub plugins {
    return (
        "Morpheus::Overrides", 
        "Morpheus::Plugin::Env",
        "Morpheus::Plugin::File::Path",
        "Morpheus::Plugin::File",
        "Morpheus::Plugin::Core",
        "Morpheus::Defaults",
    );
};

sub normalize ($) {
    my ($data) = @_;
    return unless ref $data eq "HASH";
    for my $key ( keys %$data) {
        my @keys = split /\./, $key;
        normalize($data->{$key});
        next if @keys == 1;

        my $value = delete $data->{$key};
        my $p = my $patch = {};
        $p = $p->{$_} = {} for splice @keys, 0, -1;
        merge($p->{$keys[0]}, $value);
        # {"a.b.c"=>"d"} -> {a=>{b=>{c=>"d"}}}

        merge($data, $patch);
    }
}

sub adjust ($$) {
    my ($value, $delta) = @_;
    return $value unless $delta;
    for (split /\./, $delta) {
        return undef unless defined $value and ref $value eq "HASH";
        $value = $value->{$_};
    }
    return $value;
}

sub merge ($$) {
    my ($value, $patch) = @_;

    normalize($patch);

    unless (defined $value) {
        $_[0] = $patch;
        return;
    }
    return unless defined $patch and ref $value eq "HASH" and ref $patch eq "HASH";
    
    for my $key (keys %$patch) {
        merge($value->{$key}, $patch->{$key});
    }
}

sub export ($$;$) {
    my ($package, $bindings, $root) = @_;

    $root .= "." if $root and $root !~ /\.$/;
    
    # bindings format:
    # ["$X", ...] 
    # ["@X", ...]
    # ["%X", ...]
    # ["x" => "X", ...]
    # ["x" => "$X", ...]
    # ["x" => "@X", ...]
    # ["x" => [<nested bindings>], ...]

    die "unexpected type $bindings" unless ref $bindings eq "ARRAY";
    $root ||= "";

    while (@$bindings) {
        my $ns = shift @$bindings;
        die "unexpected type $ns" if ref $ns;
        my ($var, $type, $optional);
        if ($ns =~ s/^(\??)([\$\@\%])//) {
            ($optional, $type) = ($1, $2);
            $var = $ns;
        } else {
            $var = shift @$bindings;
            if (ref $var) {
                export($package, $var, "$root$ns.");
                next;
            } else {
                $var =~ s/^(\?)// and $optional = $1;
                $type = '$';
                $var =~ s/^([\$\@\%])// and $type = $1;
            } 
        }

        die "'$var': invalid variable name" unless $var =~ /^\w+$/;
        my $symbol = do { no strict 'refs'; \*{"${package}::$var"} };        
                        
        my $value = morph("$root$ns");
        die "'$root$ns': configuration variable is not defined" unless $optional or defined $value;

        if ($type eq '$') {
            if (ref $value eq "GLOB") {
                if (defined ${*{$value}} or $optional) {
                    *$symbol = \${*{$value}};
                } else {
                    die "'$root$ns': configuration variable of type \$ is not defined";
                }
            } else {
                *$symbol = \$value;
            }
        } elsif ($type eq '@') {
            if (ref $value eq "ARRAY") {
                *$symbol = \@{$value};
            } elsif (ref $value eq "GLOB") {
                if (*{$value}{ARRAY} or $optional) {
                    *$symbol = \@{*{$value}};
                } else {
                    die "'$root$ns': configuration variable of type \@ is not defined";
                }
            } elsif ($optional) {
                *$symbol = \@{*$symbol};
            } else {
                die "'$root$ns' => '$type$var': $value is not an array or glob";
            }
        } elsif ($type eq '%') {
            if (ref $value eq "HASH") {
                *$symbol = \%{$value};
            } elsif (ref $value eq "GLOB") {
                if (*{$value}{HASH} or $optional) {
                    *$symbol = \%{*{$value}};
                } else {
                    die "'$root$ns': configuration variable of type \% is not defined";
                }
            } elsif ($optional) {
                *$symbol = \%{*$symbol};
            } else {
                die "'$root$ns' => '$type$var': $value is not a hash or glob";
            }
        } else {
            die "'$root$ns' => '$type$var': unsupported variable type $type";
        }
    }
}

our $stack = {};

sub morph (;$) {
    my ($main_ns) = @_;

    $main_ns ||= "";
    my $value;

    for my $plugin (plugins()) {

        next if $stack->{$main_ns} and $stack->{$main_ns}->{$plugin};
        local $stack->{$main_ns}->{$plugin} = 1;

        my @list = $plugin->list($main_ns);
        @list = sort {length $b <=> length $a} @list;
        for my $ns (@list) {
            
            my $patch = $plugin->morph($ns);

            if (length $main_ns > length $ns) {
                substr($main_ns, 0, length $ns) eq $ns or die;
                my $delta = substr($main_ns, length $ns);
                $delta =~ s/^\.//;
                normalize($patch);
                $patch = adjust($patch, $delta); 
            } else {
                substr($ns, 0, length $main_ns) eq $main_ns or die;
                my $delta = substr($ns, length $main_ns);
                $delta =~ s/^\.//;
                $patch = { $delta => $patch } if $delta;
                normalize($patch);
            }

            merge($value, $patch); #TODO: stop when $morphy is defined and is not a hash.
        }
    }
    return $value;
}

1;
