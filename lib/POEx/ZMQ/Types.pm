package POEx::ZMQ::Types;

use strict; use warnings FATAL => 'all';

use Type::Library   -base;
use Type::Utils     -all;
use Types::Standard -types;

use POEx::ZMQ::Constants ();

declare ZMQContext =>
  as InstanceOf['POEx::ZMQ::FFI::Context'];

declare ZMQSocket =>
  as InstanceOf['POEx::ZMQ::FFI::Socket'];

declare ZMQSocketType => as Int;
coerce  ZMQSocketType => 
  from Str() => via { POEx::ZMQ::Constants->$_ };

1;
