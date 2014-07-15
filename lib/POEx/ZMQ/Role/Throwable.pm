package POEx::ZMQ::Role::Throwable;

use Carp;
use strictures 1;


use Moo; use MooX::late;
with Throwable;


# FIXME

sub strerr {
  # FIXME
}

sub throw_if_error {
  my ($self, $call, $rc) = @_;
  # FIXME
}


1;
