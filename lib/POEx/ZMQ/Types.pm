package POEx::ZMQ::Types;

use strict; use warnings FATAL => 'all';

use Type::Library   -base;
use Type::Utils     -all;
use Types::Standard -types;

use Module::Runtime ();

use POEx::ZMQ::Constants ();

declare ZMQContext =>
  as InstanceOf['POEx::ZMQ::FFI::Context'];

declare ZMQSocketBackend =>
  as InstanceOf['POEx::ZMQ::FFI::Socket'];

declare ZMQSocket =>
  as InstanceOf['POEx::ZMQ::Socket'],
  constraint_generator => sub {
    my $want_ztype = shift;
    if (my $sub = POEx::ZMQ::Constants->can($want_ztype)) {
      $want_ztype = $sub->()
    }
    sub { $_->type == $want_ztype }
  };

declare ZMQSocketType => as Int;
coerce  ZMQSocketType => 
  from Str() => via { 
    POEx::ZMQ::Constants->can($_) ? POEx::ZMQ::Constants->$_ : undef
  };

1;

=pod

=head1 NAME

POEx::ZMQ::Types

=head1 SYNOPSIS

  use POEx::ZMQ::Types -all;

=head1 DESCRIPTION

L<Type::Tiny>-based types for L<POEx::ZMQ>.

=head2 ZMQContext

A L<POEx::ZMQ::FFI::Context> object.

=head2 ZMQSocket

A L<POEx::ZMQ::Socket> object.

=head2 ZMQSocket[`a]

A L</ZMQSocket> can be parameterized with a given L</ZMQSocketType>.

=head2 ZMQSocketBackend

A L<POEx::ZMQ::FFI::Socket> object.

=head2 ZMQSocketType

A ZMQ socket type constant, such as those exported by L<POEx::ZMQ::Constants>.

Can be coerced from a string.

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
