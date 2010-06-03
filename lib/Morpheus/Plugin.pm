package Morpheus::Plugin;
# base class for most plugins
use strict;

use Digest::MD5 qw(md5_hex);

sub _package ($$) {
    my ($self, $ns) = @_;
    my $plugin = ref $self; $plugin =~ s/^Morpheus::Plugin:://;
    $ns = "${plugin}_${ns}";
    my $md5 = md5_hex($ns);
    $ns =~ s/[^\w]/_/g;
    return "Morpheus::Sandbox::${ns}_${md5}";
}

sub content ($$) {
    my ($self, $ns) = @_;
    # return ($file => $content);
    die;
}

my %cache;

sub _process ($$) {
    my ($self, $ns) = @_;
    return if exists $self->{cache}->{$ns};

    my $package = $self->_package($ns);
    my ($file, $content) = $self->content($ns);
    return unless $content;

    # a partial evaluation support
    $self->{cache}->{$ns} = undef; 
    # this line makes it possible to properly process config blocks like
    #######################
    # $X = 5;
    # $Y = morph("X") + 1;
    #######################

    my @eval = eval qq{
no strict;
no warnings;
package $package;
# line 1 "$file"
$content
};
    die if $@;

    $self->{cache}->{$ns} = $self->_get($ns);
    unless (defined $self->{cache}->{$ns}) {
        if (@eval == 1) {
            ($self->{cache}->{$ns}) = @eval;
        } else {
            $self->{cache}->{$ns} = {@eval};
        }
    }
    die "'$file': config block should return or define something" unless defined $self->{cache}->{$ns};
}

# get a value from the stash or from cache
sub _get ($$) {
    my ($self, $ns) = @_;
    return $self->{cache}->{$ns} if defined $self->{cache}->{$ns};

    # maybe a partially evaluated config block
    my $package = $self->_package($ns);
    my $stash = do { no strict 'refs'; \%{"${package}::"} };
    my $value;
    for (keys %$stash) {
        next unless $_;
        my $glob = $stash->{$_};
        if (defined *{$glob}{ARRAY} or defined *{$glob}{HASH}) {
            $value->{$_} = \*{$glob};
        } elsif (defined ${$glob}) {
            $value->{$_} = ${$glob};
        }
    }
    return $value;
}

sub list ($$) {
    my ($self, $ns) = @_;
    return ();
}

sub morph ($$) {
    my ($self, $ns) = @_;
    $self->_process($ns);
    return $self->_get($ns);
}

sub new {
    my $class = shift;
    bless { cache => {} } => $class;
}

1;
