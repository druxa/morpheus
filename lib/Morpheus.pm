package Morpheus;
use strict;
sub normalize ($);
sub merge ($$);
sub morph ($;$);
sub export ($$;$);

use Symbol;

=head1 NAME

Morpheus - the ultimate configuration engine

=head1 SYNOPSIS

  use Morpheus "/foo/bar" => [
      qw($V1 @V2 %V3 *V4),
      "v5" => "$V5", "v6/a" => "$A", "v6/b" => "%B",
      "v7" => [ "$C", "$D", "e" => "@E" ],
  ]; 

  use Morpheus -defaults => {
      "/foo/bar" => { x => 1, y => 2},
  };

  use Morpheus -overrides => {
      "/foo/bar" => { "x/y" => 3 },
  };

  use Morpheus -export => [
      qw(morph merge normalize export)
  ];

  use Morpheus;

  morph("/foo/bar");
  morph("/foo/bar/x", "$");
  morph("/foo/bar/y", "@");

=head1 DESCRIPTION

Morph it!

=cut

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
use Morpheus::Key;

sub key {
    Morpheus::Key->new($_[0]);
}

sub normalize ($) {
    my ($data) = @_;
    return $data unless ref $data eq "HASH";
    my $result = { %$data };
    for my $key ( keys %$data) {
        my @keys = @{key($key)};
        next if @keys == 1;

        my $value = delete $result->{$key};
        my $p = my $patch = {};
        $p = $p->{$_} = {} for splice @keys, 0, -1;
        $p->{$keys[0]} = $value;
        $result = merge($result, $patch);
        # {"a/b/c"=>"d"} -> {a=>{b=>{c=>"d"}}}
    }
    return $result;
}

sub adjust ($$) {
    my ($value, $delta) = @_;
    return $value unless $delta;
    for (@{key($delta)}) {
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

sub merge ($$) {
    my ($value, $patch) = @_;

    return $patch unless defined $value;
    return $value unless defined $patch;

    my %refs = map { $_ => 1 } qw(GLOB HASH ARRAY);
   
    # TODO: return a glob itself instead of a globref!
   
    my $ref_value = ref $value;
    $ref_value = "" unless $refs{$ref_value};
    my $ref_patch = ref $patch;
    $ref_patch = "" unless $refs{$ref_patch};
    
    if ($ref_value eq "GLOB") {
        my $result = gensym;
        *{$result} = *{$value};
        if ($ref_patch eq "GLOB") {
            *{$result} = merge(*{$value}{HASH}, *{$patch}{HASH});
            *{$result} = merge(*{$value}{ARRAY}, *{$patch}{ARRAY});
            ${*{$result}} = merge(${*{$value}}, ${*{$patch}});
        } elsif ($ref_patch eq "HASH") {
            *{$result} = merge(*{$value}{HASH}, $patch);
        } elsif ($ref_patch eq "ARRAY") {
            *{$result} = merge(*{$value}{ARRAY}, $patch);
        } else {
            ${*{$result}} = merge(${*{$value}}, $patch);
        }
        return $result;
    } 
    
    if ($ref_patch eq "GLOB") {
        my $result = gensym;
        *{$result} = *{$patch};
        if ($ref_value eq "HASH") {
            *{$result} = merge($value, *{$patch}{HASH});
        } elsif ($ref_value eq "ARRAY") {
            *{$result} = $value;
        } else {
            ${*{$result}} = $value;
        }
        return $result;
    }

    if ($ref_value ne $ref_patch) {
        my $result = gensym;
        if ($ref_value) {
            *{$result} = $value;
        } else {
            ${*{$result}} = $value;
        }
        if ($ref_patch) {
            *{$result} = $patch;
        } else {
            ${*{$result}} = $patch;
        }
        return $result;
    }

    if ($ref_value eq "HASH" and $ref_patch eq "HASH") {
        my $result = { %$value };
        for (keys %$patch) {
            $result->{$_} = merge($value->{$_}, $patch->{$_});
        }
        return $result;
    }

    return $value;
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

require Data::Dump if $ENV{VERBOSE};
our $indent = "";

sub morph ($;$) {
    my ($main_ns, $type) = @_;
    $main_ns = key($main_ns);

    local $indent = "$indent  ";
    print "$indent morph($main_ns)\n" if $ENV{VERBOSE};



    unless (defined $bootstrapped) { 
        #FIXME: we just need a proper caching and its invalidation
        # then we could always call morph("/morpheus/plugins") and omit tracking if we are boostrapped or not

        my $plugins = { 
            Bootstrap => {
                priority => 1,
                object => Morpheus::Bootstrap->new(),
            },
        };

        my $plugins_prev_set;
        my $plugins_set = "";
        while () {
            local $bootstrapped = 0;

            @plugins = 
                map { { %{$plugins->{$_}}, name => $_ } } 
                sort { $plugins->{$b}->{priority} <=> $plugins->{$a}->{priority} } 
                grep { $plugins->{$_}->{priority} } keys %$plugins;

            $plugins_prev_set = $plugins_set;
            $plugins_set = join ",", map { "$_->{object}:$_->{priority}" } @plugins;
            last if $plugins_set eq $plugins_prev_set;
            #FIXME: check if we hang

            $plugins = morph("/morpheus/plugins", "%");
        }
        print "plugins: ", join (", ", map { "$_->{name}:$_->{priority}" } @plugins), "\n" if $ENV{VERBOSE};
        $bootstrapped = 1;
    }

    $main_ns ||= "";
    my $value;

    OUTER:
    #for my $plugin (@plugins) {
    
    for (@plugins) {
        my $plugin = $_->{object};
        my $plugin_name = $_->{name};
        #TODO: pass $prev_priority == $priority to merge!

        print "  $indent * ${plugin_name}->list($main_ns)\n" if $ENV{VERBOSE};
        my @list = do {
            if ($stack->{"$plugin\0$main_ns"}) {
                print "  $indent - skipped\n" if $ENV{VERBOSE};
                next;
            }
            local $stack->{"$plugin\0$main_ns"} = 1;
            $plugin->list($main_ns);
        };
        print "  $indent - done\n" if $ENV{VERBOSE};

        while (@list) {
            my ($ns, $token) = splice @list, 0, 2;
            $ns = key($ns);

            print "  $indent * ${plugin_name}->get($token)\n" if $ENV{VERBOSE};
            my $patch = do {
                if ($stack->{"$plugin\0$main_ns\0$token"}) {
                    print "  $indent - skipped\n" if $ENV{VERBOSE};
                    next;
                }
                local $stack->{"$plugin\0$main_ns\0$token"} = 1;
                $plugin->get($token);
            };
            print "  $indent - done\n" if $ENV{VERBOSE};

            if ($main_ns gt $ns) {
                my $delta = substr($main_ns, length $ns);
                $delta =~ s{^/}{};
                $patch = adjust($patch, $delta);
            } elsif ($main_ns le $ns) {
                my $delta = substr($ns, length $main_ns);
                $delta =~ s{^/}{};
                $patch = { $delta => $patch } if $delta;
            } else {
                die "$plugin: list('$main_ns'): '$ns' => '$token'"
            }

            $value = merge($value, $patch);
            # last OUTER if defined $value and ref $value ne 'HASH' and ref $value ne 'GLOB'; 
            # FIXME: actually merge now merges ARRAY and SCALAR into a GLOB. uncomment this when we get rid of globs completely
        }
    }

    $type ||= "*";
    if ($type eq '$') {
        if (ref $value eq "GLOB") {
            $value = ${*{$value}};
        }
    } elsif ($type eq '@') {
        if (ref $value eq "GLOB") {
            $value = *{$value}{ARRAY};
        } elsif (ref $value ne "ARRAY") {
            $value = undef;
        }
    } elsif ($type eq '%') {
        if (ref $value eq "GLOB") {
            $value = *{$value}{HASH};
        } elsif (ref $value ne "HASH") {
            $value = undef;
        }
    } elsif ($type ne '*') {
        die "invalid type value '$type'"
    }

    print "$indent returns ", Data::Dump::pp($value), "\n" if $ENV{VERBOSE};    
    return $value;
}

1;
