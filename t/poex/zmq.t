use Test::More;
use strict; use warnings FATAL => 'all';

use POEx::ZMQ;

can_ok __PACKAGE__, qw/
  ZMQ_ROUTER EAGAIN EINTR
/;

my $context = POEx::ZMQ->context(max_sockets => 10);
ok $context->max_sockets == 10, '->context ok';

my $sock = POEx::ZMQ->socket(context => $context, type => ZMQ_ROUTER);
isa_ok $sock, 'POEx::ZMQ::Socket';
ok $sock->context == $context, 'socket shortcut ok';

done_testing
