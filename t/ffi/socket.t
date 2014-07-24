use Test::More;
use strict; use warnings FATAL => 'all';

use Time::HiRes 'sleep';

use POEx::ZMQ::Constants -all;
use POEx::ZMQ::FFI::Context;

alarm 60;
$SIG{ALRM} = sub { die "Test timed out!" };


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

my $endpt = "ipc:///tmp/test-poex-ffi-$$";

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
cmp_ok $router->known_type_for_opt(ZMQ_IPV6), 'eq', 'int';
cmp_ok $router->known_type_for_opt(ZMQ_AFFINITY), 'eq', 'uint64';
cmp_ok $router->known_type_for_opt(ZMQ_IDENTITY), 'eq', 'binary';
cmp_ok $router->known_type_for_opt(ZMQ_PLAIN_USERNAME), 'eq', 'string';

# set_sock_opt
$router->set_sock_opt(ZMQ_SNDHWM, 100);
# get_sock_opt
cmp_ok $router->get_sock_opt(ZMQ_SNDHWM), '==', 100,
  'ZMQ_SNDHWM set/get ok';
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

done_testing
