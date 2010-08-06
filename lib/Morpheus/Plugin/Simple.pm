package Morpheus::Plugin::Simple;
use strict;
use warnings;

sub new ($$) {
    my ($class, $data) = @_;
    bless {
        data => $data
    } => $class;
}

sub list ($$) {
    return ('' => '');
}

sub get ($$) {
    my ($self, $token) = @_;
    die 'mystery' if $token;

    if (ref $self->{data} eq "CODE") {
        $self->{data} = $self->{data}->();
    }

    return $self->{data};
}

1;
