package POEx::ZMQ::FFI::Error;

use strictures 1;


use Moo; use MooX::late;
extends 'Throwable::Error';


has function => (
  required  => 1,
  is        => 'ro',
);

has errno => (
  required  => 1,
  is        => 'ro',
);

sub errstr { shift->message }


1;
