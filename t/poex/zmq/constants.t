use Test::More;
use strict; use warnings FATAL => 'all';

use POSIX ();

use POEx::ZMQ::Constants -all;

can_ok __PACKAGE__, $_ for qw/
  ZMQ_ROUTER ZMQ_DEALER ZMQ_EVENTS ZMQ_IPV6
/;

ok EAGAIN == POSIX::EAGAIN, 'POSIX EAGAIN ok';
ok EINTR  == POSIX::EINTR,   'POSIX EINTR ok';

done_testing
