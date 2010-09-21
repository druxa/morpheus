package Morpheus::Plugin::Content;
# base class for plugins that evaluate user defined perl configs
use strict;

use Morpheus::Utils qw(normalize);
use Digest::MD5 qw(md5_hex);
use Symbol qw(delete_package);

sub _package ($$) {
    my ($self, $token) = @_;
    my $md5_self = md5_hex("$self");
    my $md5 = md5_hex($token);
    $token =~ s/[^\w]/_/g;
    return "Morpheus::Sandbox::${md5_self}::${token}_${md5}";
}

sub DESTROY {
    local $@;
    my ($self) = @_;
    my $md5_self = md5_hex("$self");
    my $sandbox = "Morpheus::Sandbox::${md5_self}";
    my $stash = do { no strict qw(refs); \%{"${sandbox}::"}; };
    for (keys %$stash) {
        /^(.*)::$/ or next;
        delete_package($sandbox."::$1");
    }
    delete_package($sandbox);
}

sub content ($$) {
    my ($self, $token) = @_;
    die;
}

my %cache;

sub _process ($$) {
    my ($self, $token) = @_;
    return if exists $self->{cache}->{$token};

    my $package = $self->_package($token);
    my $content = $self->content($token);
    return unless $content;

    # a partial evaluation support
    $self->{cache}->{$token} = undef; 
    # this line makes it possible to properly process config blocks like
    #############################
    # $X = 5;
    # $Y = morph("X") + 1; # 6 
    #############################

    my @eval = eval qq{
no strict;
no warnings;
package $package;
# line 1 "$token"
$content
};
    die if $@;

    $self->{cache}->{$token} = $self->_get($token);
    unless (defined $self->{cache}->{$token}) {
        if (@eval == 1) {
            ($self->{cache}->{$token}) = @eval;
        } else {
            $self->{cache}->{$token} = {@eval};
        }
        $self->{cache}->{$token} = normalize($self->{cache}->{$token});
    }
    die "'$token': config block should return or define something" unless defined $self->{cache}->{$token};
}

# get a value from the stash or from cache
sub _get ($$) {
    my ($self, $token) = @_;
    return $self->{cache}->{$token} if defined $self->{cache}->{$token};

    # maybe a partially evaluated config block
    my $package = $self->_package($token);
    my $stash = do { no strict 'refs'; \%{"${package}::"} };
    my $value;
    for (keys %$stash) {
        next unless $_;
        my $glob = \$stash->{$_};
        if (defined *{$glob}{HASH}) {
            # warn "\%$_ defined at $token\n";
            *{$glob} = normalize(*{$glob}{HASH});
            $value->{$_} = $glob;
        } elsif (defined *{$glob}{ARRAY}) {
            # warn "\@$_ defined at $token\n";
            $value->{$_} = $glob;
        } elsif (defined ${*{$glob}}) {
            $value->{$_} = normalize(${*{$glob}});
        }
    }
    return $value;
}

sub list ($$) {
    return (); # override it
}

sub get ($$) {
    my ($self, $token) = @_;
    $self->_process($token);
    return $self->_get($token);
}

sub new {
    my $class = shift;
    bless { cache => {} } => $class;
}

1;
