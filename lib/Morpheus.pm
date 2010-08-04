package Morpheus;
use strict;
sub normalize ($);
sub merge ($$;$);
sub morph ($;$);
sub export ($$;$);

use Data::Dumper;

#
# use Morpheus -defaults => {
#   "foo/bar" => { x => 1, y => 2 },
#   "bar/baz" => "abc",
# }, -overrides => {
#   "baz/foo" => { "x/y" => 3 },
# }, "x/y/z" => [
#   qw($V1 $V2 @V3 %V4),
#   "v5" => "$V5", "v6/a" => "$A", "v6/b" => "$B",
#   "v7" => [ "$C", "$D", "e" => "@E" ],
# ], -export => [
#   qw(morph merge normalize export)
# ];
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
    *{"${caller}::$_"} = \&{$_} for @$export;
}

use Morpheus::Defaults;
use Morpheus::Overrides;
use Morpheus::Bootstrap;

sub normalize ($) {
    my ($data) = @_;
    return unless ref $data eq "HASH";
    for my $key ( keys %$data) {
        my @keys = grep {$_} split m{/}, $key;
        next if @keys == 1;

        my $value = delete $data->{$key};
        my $p = my $patch = {};
        $p = $p->{$_} = {} for splice @keys, 0, -1;
        $p->{$keys[0]} = $value;
        merge($data, $patch);
        # {"a/b/c"=>"d"} -> {a=>{b=>{c=>"d"}}}
    }
}

sub adjust ($$) {
    my ($value, $delta) = @_;
    return $value unless $delta;
    for (split m{/+}, $delta) {
        if (defined $value and ref $value eq "HASH") {
            $value = $value->{$_};
        } elsif (defined $value and ref $value eq "GLOB") {
            $value = ${*$value}{$_};
        } else {
            return (undef);
        }
    }
    return $value;
}

sub merge ($$;$) {
    my ($value, $patch, $mode) = @_;
    $mode = 1 unless defined $mode; # value priority > patch priority

    unless (defined $value) {
        $_[0] = $patch;
        return;
    } 
    unless (defined $patch) {
        return;
    }

    #TODO: support mode "-1" (value priority < patch priority)
    if (ref $value eq "GLOB" and *{$value}{HASH}) {
        $value = \%{*{$value}};
    }
    if (ref $patch eq "GLOB" and *{$patch}{HASH}) {
        $patch = \%{*{$patch}};
    }

    unless (defined $patch and ref $value eq "HASH" and ref $patch eq "HASH") {
        die "merge: collision" if $mode == 0; #FIXME: dump keys stack
        return;
    }

    for my $key (keys %$patch) {
        merge($value->{$key}, $patch->{$key}, $mode);
    }
}

sub export ($$;$) {
    my ($package, $bindings, $root) = @_;

    # bindings format:
    # ["$X", ...]
    # ["@X", ...]
    # ["%X", ...]
    # ["x" => "X", ...]
    # ["x" => "$X", ...]
    # ["x" => "@X", ...]
    # ["x" => [<nested bindings>], ...]

    die "unexpected type $bindings" unless ref $bindings eq "ARRAY" or ref $bindings eq "SCALAR";
    $root ||= "";

    if (ref $bindings eq "SCALAR") {

        my $value = morph("$root");
        die "'$root': configuration variable is not defined" unless defined $value;

       if (ref $value eq "GLOB") {
            if (defined ${*{$value}}) {
                $$bindings = ${*{$value}};
            } else {
                die "'$root': configuration variable of type \$ is not defined";
            }
        } else {
            $$bindings = $value;
        }

        return;
    }

    $root .= "/" if $root and $root !~ m{/$};

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

                die "'$root$ns' => '$type$var': $value is not an array or glob: " . ref $value;
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
our $bootstrapped;
our @plugins;

sub morph ($;$) {
    my ($main_ns, $type) = @_;

    unless (defined $bootstrapped) { 
        #FIXME: we just need a proper caching and its invalidation
        # then we could always call morph("/morpheus/plugins") and omit tracking if we are boostrapped or not

        my $plugins = { 
            Bootstrap => {
                priority => 1,
                object => 'Morpheus::Bootstrap',
            },
        };

        while () {
            local $bootstrapped = 0;
            @plugins = map { $_->{object} } sort { $b->{priority} <=> $a->{priority} } grep { $_->{priority} } values %$plugins;
            my $plugins_set = join ",", map { "$_:$plugins->{$_}->{priority}" } sort { $plugins->{$b}->{priority} <=> $plugins->{$a}->{priority} } grep { $plugins->{$_}->{priority} } keys %$plugins;
            warn "plugins_before: $plugins_set";
            $plugins = morph("/morpheus/plugins", "%");
            my $plugins_set2 = join ",", map { "$_:$plugins->{$_}->{priority}" } sort { $plugins->{$b}->{priority} <=> $plugins->{$a}->{priority} } grep { $plugins->{$_}->{priority} } keys %$plugins;
            warn "plugins_after: $plugins_set2";
            last if $plugins_set eq $plugins_set2;
            #FIXME: check if we hang
        }
        $bootstrapped = 1;
    }

    $main_ns ||= "";
    my $value;

    OUTER:
    for my $plugin (@plugins) {

        my @list = do {
            next if $stack->{"$plugin\0$main_ns"};
            local $stack->{"$plugin\0$main_ns"} = 1;
            $plugin->list($main_ns);
        };
        @list = sort {length $b <=> length $a} @list;
        for my $ns (@list) {

            my $patch = do {
                next if $stack->{"$plugin\0$main_ns\0$ns"};
                local $stack->{"$plugin\0$main_ns\0$ns"} = 1;
                $plugin->morph($ns);
            };

            if (length $main_ns > length $ns) {
                substr($main_ns, 0, length $ns) eq $ns or die "$plugin: list('$main_ns'): '$ns'";
                my $delta = substr($main_ns, length $ns);
                $delta =~ s{^/}{};
                $patch = adjust($patch, $delta);
            } else {
                substr($ns, 0, length $main_ns) eq $main_ns or die "$plugin: list('$main_ns'): '$ns'";
                my $delta = substr($ns, length $main_ns);
                $delta =~ s{^/}{};
                $patch = { $delta => $patch } if $delta;
            }

            merge($value, $patch);
            last OUTER if defined $value and ref $value ne 'HASH' and ref $value ne 'GLOB';
        }
    }
    if ($type and ref $value eq "GLOB") {
        if ($type eq '$') {
            $value = ${*{$value}};
        } elsif ($type eq '@') {
            $value = \@{*{$value}};
        } elsif ($type eq '%') {
            $value = \%{*{$value}};
        } else {
            die "invalid type value '$type'"
        }
    }

    #use Yandex::Logger;
    #DEBUG "$main_ns affects: ", join ", ", keys %$stack;

    return $value;
}

1;
