package POEx::ZMQ::FFI::Socket;

use Carp;
use strictures 1;


use Moo; use MooX::late;


has context => ();

has type    => ();

has soname  => ();


with 'POEx::ZMQ::FFI::Role::ErrorChecking';





1;
