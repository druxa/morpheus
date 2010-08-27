package Morpheus::Plugin::Simple;
use strict;
use warnings;
use Morpheus -export => [qw(normalize)];

sub new ($$) {
    my ($class, $data) = @_;
    my $_data = $data;
    $data = sub { $_data } unless ref $data eq "CODE";
    bless {
        data => $data,
    } => $class;
}

sub list ($$) {
    return ('' => '');
}

sub get ($$) {
    my ($self, $token) = @_;
    die 'mystery' if $token;

    if (ref $self->{data} eq "CODE") {
        $self->{data} = normalize($self->{data}->());
    }

    return $self->{data};
}

1;
