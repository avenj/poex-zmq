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
{
  my $temp = POEx::ZMQ::FFI::Context->new(
    max_sockets => 10,
    threads     => 2,
  );
  cmp_ok $temp->get_ctx_opt(ZMQ_IO_THREADS), '==', 2,
    'get_sock_opt and threads attr agree';
  cmp_ok $temp->get_ctx_opt(ZMQ_MAX_SOCKETS), '==', 10,
    'get_sock_opt and max_sockets attr agree';
}

# set_ctx_opt
$ctx->set_ctx_opt(ZMQ_IO_THREADS, 3);
cmp_ok $ctx->get_ctx_opt(ZMQ_IO_THREADS), '==', 3,
  'set_ctx_opt ZMQ_IO_THREADS ok';

# get_raw_context
ok $ctx->get_raw_context > -1, 'get_raw_context ok';

# generate_keypair
# FIXME need a consistent way to determine if we have CURVE support or not
# in the meantime here's a pretty useless test:
my $kpair;
eval {; $kpair = $ctx->generate_keypair };
if (!$@) {
  cmp_ok length($kpair->public), '==', 40, 'pubkey is 40 chrs';
  cmp_ok length($kpair->secret), '==', 40, 'seckey is 40 chrs';
}

done_testing
