package Morpheus::Plugin::DB;
use strict;

use base qw(Morpheus::Plugin);

use Morpheus -defaults => {
    "morpheus/plugin/db/options" => {
        table => "Morpheus",
        key => "Name",
        value => "Config",
    },
}, -export => [];

use DBI;

sub content ($$) {
    my ($self, $ns) = @_;

    my $options = $self->{options};
    my $dbh = $options->{connect}->();
    
    my ($content) = $dbh->selectrow_array(qq#
        select `$options->{value}` from `$options->{table}`
        where `$options->{key}` = ?
    #, undef, $ns);
    return ("$options->{table}.$options->{value}\[$options->{key} = $ns\]" => $content);
}

my %escape = ("_" => "\\_", "%" => "\\%", "\\" => "\\\\");

sub list ($$) {
    my ($self, $main_ns) = @_;

    $main_ns =~ s{/+}{/}g;
    $main_ns =~ s{/$}{};
    $main_ns =~ s{^/}{};

    unless ($self->{options}->{connect}) {
        $self->{options} = Morpheus::morph("morpheus/plugin/db/options");
    }
    my $options = $self->{options};
    return () unless $options->{connect};
    my $dbh = $options->{connect}->();

    my $pattern = $main_ns;
    $pattern =~ s/([_%\\])/$escape{$1}/g;

    my @prefix;
    my $ns = $main_ns;
    while ($ns) {
        push @prefix, $ns;
        $ns =~ s{/?[^/]+$}{};
    }
    push @prefix, "";

    my @list = @{$dbh->selectcol_arrayref(qq#
        select `$options->{key}` from `$options->{table}`
        where `$options->{key}` like ? or `$options->{key}` in (#. join (",", ("?") x @prefix) .qq#)
    #, undef, "$pattern/%", @prefix)};
    
    return @list;
}

1;
