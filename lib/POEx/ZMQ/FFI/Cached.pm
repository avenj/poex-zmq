package POEx::ZMQ::FFI::Cached;

use Carp;
use strictures 1;

use Scalar::Util 'blessed';

our %Cache;

sub get {
  my (undef, $classtype, $soname) = @_;
  confess "Expected cached obj type and soname"
    unless defined $classtype and defined $soname;
  $Cache{ $classtype . $soname }
}

sub set {
  my (undef, $classtype, $soname, $callable_ffi) = @_;

  confess "Expected cached obj type, soname, and Callable FFI obj"
    unless defined $classtype
    and    defined $soname
    and    defined $callable_ffi;

  confess "Expected a POEx::ZMQ::FFI::Callable but got $callable_ffi"
    unless blessed $callable_ffi
    and    $callable_ffi->isa('POEx::ZMQ::FFI::Callable');

  $Cache{ $classtype . $soname } = $callable_ffi
}

sub clear {
  my (undef, $classtype, $soname) = @_;
  delete $Cache{ $classtype . $soname }
}

1;
