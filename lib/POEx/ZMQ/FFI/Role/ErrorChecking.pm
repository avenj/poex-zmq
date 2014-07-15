package POEx::ZMQ::FFI::Role::ErrorChecking;

use Carp;
use strictures 1;


use POEx::ZMQ::FFI::Error;


use Moo::Role;


sub throw_if_error {
  my ($self, $call, $rc) = @_;
  confess "Expected function name and return code"
    unless defined $call and defined $rc;
  # FIXME
}


1;
