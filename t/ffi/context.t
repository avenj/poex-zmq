use Test::More;
use strict; use warnings FATAL => 'all';

use POEx::ZMQ::Constants -all;
use POEx::ZMQ::FFI::Context;

my $ctx = POEx::ZMQ::FFI::Context->new;

{
  # attr builders
  #  (BUILD depends on max_sockets / threads predicates, tested separately
  #   here)
  my $temp = POEx::ZMQ::FFI::Context->new;
  ok $temp->max_sockets == 1023, 'max_sockets ok';
  ok $temp->threads == 1, 'threads ok';
  ok $temp->soname, 'soname ok';
}

cmp_ok $ctx->get_zmq_version->major, '>=', 3, 'get_zmq_version ok';

# create_socket
my $zsock = $ctx->create_socket( ZMQ_PUB );
isa_ok $zsock, 'POEx::ZMQ::FFI::Socket';
my $second = $ctx->create_socket( ZMQ_SUB );
isa_ok $second, 'POEx::ZMQ::FFI::Socket';

# get_ctx_opt
# FIXME

# set_ctx_opt
# FIXME

# get_raw_context
# FIXME


done_testing
