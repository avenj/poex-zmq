use Test::More;
use strict; use warnings FATAL => 'all';

use POEx::ZMQ;

can_ok __PACKAGE__, qw/
  ZMQ_ROUTER EAGAIN EINTR
/;

my $context = POEx::ZMQ->context(max_sockets => 10);
ok $context->max_sockets == 10, '->context ok';

done_testing
