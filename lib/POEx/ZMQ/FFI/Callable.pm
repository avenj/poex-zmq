package POEx::ZMQ::FFI::Callable;

use Carp ();
use Scalar::Util ();
use strictures 1;

=for Pod::Coverage .*

=cut

sub new {
  bless +{ @_[1 .. $#_] }, $_[0]
}

sub METHODS { keys %{ $_[0] } }
sub FETCH   { $_[0]->{ $_[1] } }
sub EXPORT  { +{ %{ $_[0] } } }


our $AUTOLOAD;

sub can {
  my ($self, $method) = @_;
  if (my $sub = $self->SUPER::can($method)) {
    return $sub
  }
  return unless exists $self->{$method};
  sub {
    my ($self) = @_;
    if (my $sub = $self->SUPER::can($method)) {
      goto $sub
    }
    $AUTOLOAD = $method;
    goto &AUTOLOAD
  }
}

sub AUTOLOAD {
  my $self = shift;
  ( my $method = $AUTOLOAD ) =~ s/.*:://;
  Scalar::Util::blessed($self)
    or Carp::confess "Not a class method: '$method'";

  Carp::confess "Can't locate object method '$method'"
    unless exists $self->{$method};

  $self->{$method}->(@_)
}

sub DESTROY {}


1;
