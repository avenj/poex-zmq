package POEx::ZMQ::Types;

use strict; use warnings FATAL => 'all';

use Type::Library   -base;
use Type::Utils     -all;
use Types::Standard -types;

use POEx::ZMQ::Constants ();

declare ZMQContext =>
  as HasMethods[ qw/
    get set
    socket
    destroy
  / ];


declare ZMQSocket =>
  as HasMethods[ qw/
    get set
    get_fd
    has_pollin has_pollout
    send send_multipart
    recv recv_multipart
    connect disconnect
    bind unbind
    close
  / ];


declare ZMQSocketType => as Int;
coerce  ZMQSocketType => 
  from Str() => via { POEx::ZMQ::Constants->$_ };

1;
