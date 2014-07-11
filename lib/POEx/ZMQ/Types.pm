package POEx::ZMQ::Types;

use strict; use warnings FATAL => 'all';

use Type::Library   -base;
use Type::Utils     -all;
use Types::Standard -types;

use ZMQ::FFI::Constants ':all';


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


declare ZMQSocketType => as Str();
# FIXME haven't decided if I really want to hardcode these ^


1;
