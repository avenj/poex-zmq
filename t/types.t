use strict; use warnings FATAL => 'all';
use Test::More;
use Test::TypeTiny;

use POEx::ZMQ::Types -all;

use POEx::ZMQ;

# ZMQContext
my $ctx = POEx::ZMQ->context;
should_pass $ctx, ZMQContext;
should_fail bless([]), ZMQContext;

# ZMQSocketBackend
use POEx::ZMQ::FFI::Socket;
my $ffi = POEx::ZMQ::FFI::Socket->new(
  context => $ctx, type => ZMQ_ROUTER
);

should_pass $ffi, ZMQSocketBackend;
should_fail bless([]), ZMQSocketBackend;

# ZMQSocket, ZMQSocket[$type]
my $rtr = POEx::ZMQ->socket(type => ZMQ_ROUTER);
should_pass $rtr, ZMQSocket;
should_pass $rtr, ZMQSocket[ZMQ_ROUTER];
should_pass $rtr, ZMQSocket['ZMQ_ROUTER'];
should_fail $rtr, ZMQSocket[ZMQ_REP];
should_fail $rtr, ZMQSocket['ZMQ_REP'];
should_fail bless([]), ZMQSocket;
should_fail bless([]), ZMQSocket['ZMQ_ROUTER'];
should_fail bless([]), ZMQSocket[ZMQ_ROUTER];

# ZMQSocketType
should_pass ZMQ_ROUTER, ZMQSocketType;
should_fail 'foo',      ZMQSocketType;


done_testing
