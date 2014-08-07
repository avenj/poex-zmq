use Test::More;
use strict; use warnings FATAL => 'all';

use Time::HiRes 'sleep';

use POEx::ZMQ::Constants -all;
use POEx::ZMQ::FFI::Context;

use File::Temp ();
my $tempdir = File::Temp::tempdir(CLEANUP => 1);
my $endpt = "ipc://$tempdir/test-poex-ffi-$$";

alarm 60;
$SIG{ALRM} = sub { die "Test timed out!" };

# New scope to test destruction:
{
  my $ctx = POEx::ZMQ::FFI::Context->new;

  # Socket->new
  my $router = $ctx->create_socket(ZMQ_ROUTER);
  my $req    = $ctx->create_socket(ZMQ_REQ);

  # context
  isa_ok $router->context, 'POEx::ZMQ::FFI::Context';

  # type
  ok $router->type == ZMQ_ROUTER, 'type ok';

  # soname
  ok $router->soname, 'soname ok';

  # connect
  $req->connect($endpt);

  # bind
  $router->bind($endpt);

  my $first  = 'foo bar';
  my $second = 'quux';

  # send
  $req->send($first);

  # has_event_pollin
  until ($router->has_event_pollin) {
    sleep 0.1;
  }

  # recv_multipart
  my $chunks = $router->recv_multipart;
  ok $chunks->isa('List::Objects::WithUtils::Array'),
    'recv_multipart returned array-type obj';
  ok $chunks->count == 3, 'multipart obj has 3 parts';
    
  my ($id, $nul, $content) = $chunks->all;
  ok defined($id), 'router recv_multipart ok';
  cmp_ok $nul, 'eq', '', 'null part empty';
  cmp_ok $content, 'eq', $first, 'content part ok'
    or diag explain $content;

  # send_multipart
  $router->send_multipart(
    [ $id, '', $second ] 
  );

  until ($req->has_event_pollin) {
    sleep 0.1;
  }

  # recv
  my $req_got = $req->recv;
  cmp_ok $req_got, 'eq', $second, 'req recv ok'
    or diag explain $req_got;


  # known_type_for_opt
  cmp_ok $router->known_type_for_opt(ZMQ_IPV6), 'eq', 'int',
    'known_type_for_opt int ok';
  cmp_ok $router->known_type_for_opt(ZMQ_AFFINITY), 'eq', 'uint64',
    'known_type_for_opt uint64 ok';
  cmp_ok $router->known_type_for_opt(ZMQ_IDENTITY), 'eq', 'binary',
    'known_type_for_opt binary ok';
  cmp_ok $router->known_type_for_opt(ZMQ_PLAIN_USERNAME), 'eq', 'string',
    'known_type_for_opt string ok';

  # set_sock_opt (int)
  $router->set_sock_opt(ZMQ_SNDHWM, 100);

  # get_sock_opt (int)
  cmp_ok $router->get_sock_opt(ZMQ_SNDHWM), '==', 100,
    'ZMQ_SNDHWM (int) set/get ok';

  # set_sock_opt (uint64)
  $router->set_sock_opt(ZMQ_AFFINITY, 2);
  # get_sock_opt (uint64)
  cmp_ok $router->get_sock_opt(ZMQ_AFFINITY), '==', 2,
    'ZMQ_AFFINITY (uint64) set/get ok';
  $router->set_sock_opt(ZMQ_AFFINITY, 1);

  # set_sock_opt (string)
  # FIXME version check, test ZMQ_PLAIN_USERNAME
  # get_sock_opt (string)
  # FIXME

  # set_sock_opt (binary)
  $router->set_sock_opt(ZMQ_IDENTITY, 'foo');
  # get_sock_opt (binary)
  cmp_ok $router->get_sock_opt(ZMQ_IDENTITY), 'eq', 'foo',
    'ZMQ_IDENTITY set/get ok';

  # FIXME test w explicit types
  # FIXME test exception w bad type

  # get_handle
  my $fh = $router->get_handle;
  isa_ok $fh, 'IO::Handle';
  cmp_ok $router->get_sock_opt(ZMQ_FD), '==', $fh->fileno,
    'ZMQ_FD == fileno(socket->get_handle)';
  undef $fh;

  # unbind
  # FIXME

  # disconnect
  # FIXME
}

pass "Nobody croaked after object destruction";

done_testing
