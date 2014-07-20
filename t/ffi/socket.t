use Test::More;
use strict; use warnings FATAL => 'all';

use Time::HiRes 'sleep';

use POEx::ZMQ::Constants -all;
use POEx::ZMQ::FFI::Context;

alarm 60;
$SIG{ALRM} = sub { die "Test timed out!" };


my $ctx = POEx::ZMQ::FFI::Context->new;

my $router = $ctx->create_socket(ZMQ_ROUTER);
my $req    = $ctx->create_socket(ZMQ_REQ);

my $endpt = "ipc:///tmp/test-poex-ffi-$$";

$req->connect($endpt);
$router->bind($endpt);

my $first  = 'foo bar';
my $second = 'quux';

$req->send($first);

until ($router->has_event_pollin) {
  sleep 0.1;
}

my $chunks = $router->recv_multipart;
ok $chunks->isa('List::Objects::WithUtils::Array'),
  'recv_multipart returned array-type obj';
ok $chunks->count == 3, 'multipart obj has 3 parts';
  
my ($id, $nul, $content) = $chunks->all;
ok defined($id), 'router recv_multipart ok';
cmp_ok $nul, 'eq', '', 'null part empty';
cmp_ok $content, 'eq', $first, 'content part ok'
  or diag explain $content;

$router->send_multipart(
  [ $id, '', $second ] 
);

until ($req->has_event_pollin) {
  sleep 0.1;
}

my $req_got = $req->recv;
cmp_ok $req_got, 'eq', $second, 'req recv ok'
  or diag explain $req_got;

done_testing
