package POEx::ZMQ::FFI::Socket;

use Carp;
use strictures 1;

use IO::Handle ();

use List::Objects::WithUtils;

use Types::Standard  -types;
use POEx::ZMQ::Types -types;

use POEx::ZMQ::Constants -all;
use POEx::ZMQ::FFI;

use FFI::Raw;


# Large enough to hold ZMQ_IDENTITY / ZMQ_LAST_ENDPOINT:
sub OPTVAL_MAXLEN () { 256 }


use Moo; use MooX::late;


has context => (
  required  => 1,
  is        => 'ro',
  isa       => InstanceOf['POEx::ZMQ::FFI::Context'],
);

has type    => (
  required  => 1,
  is        => 'ro',
  isa       => ZMQSocketType,
);

has soname  => (
  required  => 1,
  is        => 'ro',
  isa       => Str,
);


has _ffi => (
  is        => 'ro',
  isa       => InstanceOf['POEx::ZMQ::FFI::Callable'],
  builder   => sub {
    my $soname = shift->soname;
    POEx::ZMQ::FFI::Callable->new(
      zmq_socket => FFI::Raw->new(
        $soname, zmq_socket =>
          FFI::Raw::ptr,  # <- socket ptr
          FFI::Raw::ptr,  # -> context ptr
          FFI::Raw::int,  # -> socket type
      ),

      zmq_getsockopt => FFI::Raw->new(
        $soname, zmq_getsockopt =>
          FFI::Raw::int,  # <- rc
          FFI::Raw::ptr,  # -> socket ptr
          FFI::Raw::int,  # -> opt (constant)
          FFI::Raw::ptr,  # -> opt value ptr
          FFI::Raw::ptr,  # -> value len ptr
      ),

      zmq_setsockopt_int => FFI::Raw->new(
        $soname, zmq_setsockopt =>
          FFI::Raw::int,  # <- rc
          FFI::Raw::ptr,  # -> socket ptr
          FFI::Raw::int,  # -> opt (constant)
          FFI::Raw::ptr,  # -> opt value ptr (int)
          FFI::Raw::int,  # -> opt value len
      ),
      zmq_setsockopt_str => FFI::Raw->new(
        $soname, zmq_setsockopt =>
          FFI::Raw::int,  # <- rc
          FFI::Raw::ptr,  # -> socket ptr
          FFI::Raw::int,  # -> opt (constant)
          FFI::Raw::str,  # -> opt value ptr (str)
          FFI::Raw::int,  # -> opt value len
      ),

      zmq_connect => FFI::Raw->new(
        $soname, zmq_connect =>
          FFI::Raw::int,  # <- rc
          FFI::Raw::ptr,  # -> socket ptr
          FFI::Raw::str,  # -> endpoint str
      ),

      zmq_disconnect => FFI::Raw->new(
        $soname, zmq_disconnect =>
          FFI::Raw::int,  # <- rc
          FFI::Raw::ptr,  # -> socket ptr
          FFI::Raw::str,  # -> endpoint str
      ),

      zmq_bind => FFI::Raw->new(
        $soname, zmq_bind =>
          FFI::Raw::int,  # <- rc
          FFI::Raw::ptr,  # -> socket ptr
          FFI::Raw::str,  # -> endpoint str
      ),

      zmq_unbind => FFI::Raw->new(
        $soname, zmq_unbind =>
          FFI::Raw::int,  # <- rc
          FFI::Raw::ptr,  # -> socket ptr
          FFI::Raw::str,  # -> endpoint str
      ),

      zmq_msg_init => FFI::Raw->new(
        $soname, zmq_msg_init =>
          FFI::Raw::int,  # <- rc
          FFI::Raw::ptr,  # -> zmq_msg_t ptr
      ),

      zmq_msg_init_size => FFI::Raw->new(
        $soname, zmq_msg_init_size =>
          FFI::Raw::int,  # <- rc
          FFI::Raw::ptr,  # -> zmq_msg_t ptr
          FFI::Raw::int,  # -> len
      ),

      zmq_msg_size => FFI::Raw->new(
        $soname, zmq_msg_size =>
          FFI::Raw::int,  # <- len
          FFI::Raw::ptr,  # -> zmq_msg_t ptr
      ),

      zmq_msg_data => FFI::Raw->new(
        $soname, zmq_msg_data =>
          FFI::Raw::ptr,  # <- msg data ptr
          FFI::Raw::ptr,  # -> zmq_msg_t ptr
      ),

      zmq_msg_close => FFI::Raw->new(
        $soname, zmq_msg_close =>
          FFI::Raw::int,  # <- rc
          FFI::Raw::ptr,  # -> zmq_msg_t ptr
      ),

      zmq_msg_recv => FFI::Raw->new(
        $soname, zmq_msg_recv =>
          FFI::Raw::int,  # <- rc
          FFI::Raw::ptr,  # -> zmq_msg_t ptr
          FFI::Raw::ptr,  # -> socket ptr
          FFI::Raw::int,  # -> flags
      ),

      zmq_send => FFI::Raw->new(
        $soname, zmq_send =>
          FFI::Raw::int,  # <- rc
          FFI::Raw::ptr,  # -> socket ptr
          FFI::Raw::str,  # -> msg
          FFI::Raw::int,  # -> len
          FFI::Raw::int,  # -> flags
      ),

      zmq_close => FFI::Raw->new(
        $soname, zmq_close =>
          FFI::Raw::int,  # <- rc
          FFI::Raw::ptr,  # -> socket ptr
      ),

      memcpy => FFI::Raw->new(
        undef, memcpy =>
          FFI::Raw::ptr,  # <- dest ptr
          FFI::Raw::ptr,  # -> dest buf ptr
          FFI::Raw::ptr,  # -> src
          FFI::Raw::int,  # -> len
      ),
    )
  },
);

has _socket_ptr => (
  lazy      => 1,
  is        => 'ro',
  writer    => '_set_socket_ptr',
  builder   => sub {
    # FIXME
  },
);


with 'POEx::ZMQ::FFI::Role::ErrorChecking';


# Incomplete, but common-ish constant => type pairs:
our $KnownTypes = hash;
$KnownTypes->set( $_ => 'int' ) for (
  ZMQ_EVENTS,             #
  ZMQ_FD,                 #
  ZMQ_IMMEDIATE,          # 3.3
  ZMQ_IPV4ONLY,           # deprecated by ZMQ_IPV6
  ZMQ_IPV6,               # 3.3
  ZMQ_LINGER,             #
  ZMQ_PLAIN_SERVER,       # 4.0
  ZMQ_CURVE_SERVER,       # 4.0
  ZMQ_PROBE_ROUTER,       # 4.0
  ZMQ_ROUTER_MANDATORY,   #
  ZMQ_ROUTER_RAW,         # 3.3
  ZMQ_RCVMORE,            #
  ZMQ_RCVHWM,             #
  ZMQ_SNDHWM,             #
  ZMQ_RCVTIMEO,           #
  ZMQ_SNDTIMEO,           #
);
$KnownTypes->set( $_ => 'binary' ) for (
  ZMQ_IDENTITY,           #
  ZMQ_SUBSCRIBE,          #
  ZMQ_UNSUBSCRIBE,        #
  ZMQ_CURVE_PUBLICKEY,    # 4.0
  ZMQ_CURVE_SECRETKEY,    # 4.0
  ZMQ_CURVE_SERVERKEY,    # 4.0
);
$KnownTypes->set( $_ => 'string' ) for (
  ZMQ_LAST_ENDPOINT,      #
  ZMQ_PLAIN_USERNAME,     # 4.0
  ZMQ_PLAIN_PASSWORD,     # 4.0
  ZMQ_ZAP_DOMAIN,         # 4.0
);

sub known_type_for_opt { $KnownTypes->get($_[1]) }

sub get_sock_opt {
  my ($self, $opt, $type) = @_;
  my ($val, $ptr, $len);

  unless (defined $type) {
    $type = $KnownTypes->exists($opt) ? $KnownTypes->get($opt)
      : confess "No return type specified and none known to us (opt $opt)"
  }

  if ($type eq 'binary' || $type eq 'string') {
    $ptr = FFI::Raw::memptr( OPTVAL_MAXLEN );
    $len = pack 'L!', OPTVAL_MAXLEN;
  } else {
    $val = POEx::ZMQ::FFI->zpack($type, 0);
    $ptr = unpack 'L!', pack 'P', $val;
    $len = pack 'L!', length $val;
  }

  my $len_ptr = unpack 'L!', pack 'P', $len;
  $self->throw_if_error( zmq_getsockopt =>
    $self->_ffi->zmq_getsockopt(
      $self->_socket_ptr, $opt, $ptr, $len_ptr
    )
  );

  POEx::ZMQ::FFI->zunpack($type, $val, $ptr, $len)
}

sub set_sock_opt {
  my ($self, $opt, $val, $type) = @_;

  unless (defined $type) {
    $type = $KnownTypes->exists($opt) ? $KnownTypes->get($opt)
      : confess "No opt type specified and none known to us (opt $opt)"
  }

  # FIXME
}


sub get_handle {
  my ($self) = @_;
  my $fno = $self->get_sock_opt( ZMQ_FD, 'int' );
  IO::Handle->new_from_fd( $fno, 'r' )
}


sub connect {

}

sub disconnect {

}

sub bind {

}

sub unbind {

}

sub send {

}

sub send_multipart {

}

sub recv {

}

sub recv_multipart {

}

1;
