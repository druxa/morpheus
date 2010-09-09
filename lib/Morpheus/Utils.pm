package Morpheus::Utils;
use strict;

use parent qw(Exporter);
our @EXPORT = qw(normalize merge adjust);

use Symbol qw(gensym);

use Morpheus::Key qw(key);

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
            my $hash = merge(*{$value}{HASH}, *{$patch}{HASH});
            *{$result} = $hash if $hash;
            my $array = merge(*{$value}{ARRAY}, *{$patch}{ARRAY});
            *{$result} = $array if $array;
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



