package POEx::ZMQ::FFI::Socket;

use v5.10;
use Carp;
use strictures 1;

require bytes;
require IO::Handle;

use List::Objects::WithUtils;

use Types::Standard  -types;
use POEx::ZMQ::Types -types;

use POEx::ZMQ::Constants -all;
use POEx::ZMQ::FFI;
use POEx::ZMQ::FFI::Callable;

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

      int_zmq_setsockopt => FFI::Raw->new(
        $soname, zmq_setsockopt =>
          FFI::Raw::int,  # <- rc
          FFI::Raw::ptr,  # -> socket ptr
          FFI::Raw::int,  # -> opt (constant)
          FFI::Raw::ptr,  # -> opt value ptr (int)
          FFI::Raw::int,  # -> opt value len
      ),
      str_zmq_setsockopt => FFI::Raw->new(
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
  isa       => Defined,
  writer    => '_set_socket_ptr',
  builder   => sub {
    my ($self) = @_;
    my $zsock = 
      $self->_ffi->zmq_socket( $self->context->get_raw_context, $self->type );
    $self->recv while $self->has_event_pollin;
    $zsock
  },
);


with 'POEx::ZMQ::FFI::Role::ErrorChecking';


our $KnownTypes = hash;
$KnownTypes->set( $_ => 'int' ) for (
  ZMQ_BACKLOG,            #
  ZMQ_CONFLATE,           # 4.0
  ZMQ_DELAY_ATTACH_ON_CONNECT,
  ZMQ_EVENTS,             #
  ZMQ_FD,                 #
  ZMQ_IMMEDIATE,          # 3.3
  ZMQ_IPV4ONLY,           # deprecated by ZMQ_IPV6
  ZMQ_IPV6,               # 3.3
  ZMQ_LINGER,             #
  ZMQ_MULTICAST_HOPS,     #
  ZMQ_PLAIN_SERVER,       # 4.0
  ZMQ_CURVE_SERVER,       # 4.0
  ZMQ_PROBE_ROUTER,       # 4.0
  ZMQ_RATE,               #
  ZMQ_RECOVERY_IVL,       #
  ZMQ_RECONNECT_IVL,      #
  ZMQ_RECONNECT_IVL_MAX,  #
  ZMQ_REQ_CORRELATE,      # 4.0
  ZMQ_REQ_RELAXED,        # 4.0
  ZMQ_ROUTER_MANDATORY,   #
  ZMQ_ROUTER_RAW,         # 3.3
  ZMQ_RCVBUF,             #
  ZMQ_RCVMORE,            #
  ZMQ_RCVHWM,             #
  ZMQ_RCVTIMEO,           #
  ZMQ_SNDHWM,             #
  ZMQ_SNDTIMEO,           #
  ZMQ_SNDBUF,             #
  ZMQ_XPUB_VERBOSE,       #
);
$KnownTypes->set( $_ => 'uint64' ) for (
  ZMQ_AFFINITY,           #
  ZMQ_MAXMSGSIZE,         #
);
$KnownTypes->set( $_ => 'binary' ) for (
  ZMQ_IDENTITY,           #
  ZMQ_SUBSCRIBE,          #
  ZMQ_UNSUBSCRIBE,        #
  ZMQ_CURVE_PUBLICKEY,    # 4.0
  ZMQ_CURVE_SECRETKEY,    # 4.0
  ZMQ_CURVE_SERVERKEY,    # 4.0
  ZMQ_TCP_ACCEPT_FILTER,  #
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
    $type = $self->known_type_for_opt($opt)
      // confess "No return type specified and none known to us (opt $opt)"
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
    $type = $self->known_type_for_opt($opt)
      // confess "No opt type specified and none known to us (opt $opt)"
  }

  if ($type eq 'binary' || $type eq 'string') {
    $self->throw_if_error( zmq_setsockopt =>
      $self->_ffi->str_zmq_setsockopt(
        $self->_socket_ptr, $opt, $val, length $val
      )
    );
  } else {
    my $packed = POEx::ZMQ::FFI->zpack($type, $val);
    my $ptr = unpack 'L!', pack 'P', $packed;
    $self->throw_if_error( zmq_setsockopt =>
      $self->_ffi->int_zmq_setsockopt(
        $self->_socket_ptr, $opt, $ptr, length $packed
      )
    )
  }

  $self
}


sub get_handle {
  my ($self) = @_;
  my $fno = $self->get_sock_opt( ZMQ_FD );
  IO::Handle->new_from_fd( $fno, 'r' )
}


sub connect {
  my ($self, $endpoint) = @_;
  confess "Expected an endpoint" unless defined $endpoint;

  $self->throw_if_error( zmq_connect =>
    $self->_ffi->zmq_connect( $self->_socket_ptr, $endpoint )
  );

  $self
}

sub disconnect {
  my ($self, $endpoint) = @_;
  confess "Expected an endpoint" unless defined $endpoint;

  $self->throw_if_error( zmq_disconnect =>
    $self->_ffi->zmq_disconnect( $self->_socket_ptr, $endpoint )
  );

  $self
}

sub bind {
  my ($self, $endpoint) = @_;
  confess "Expected an endpoint" unless defined $endpoint;

  $self->throw_if_error( zmq_bind =>
    $self->_ffi->zmq_bind( $self->_socket_ptr, $endpoint )
  );

  $self
}

sub unbind {
  my ($self, $endpoint) = @_;
  confess "Expected an endpoint" unless defined $endpoint;

  $self->throw_if_error( zmq_unbind =>
    $self->_ffi->zmq_unbind( $self->_socket_ptr, $endpoint )
  );

  $self
}

sub send {
  my ($self, $msg, $flags) = @_;
  $flags //= 0;
  my $len = bytes::length($msg);
  $self->throw_if_error( zmq_send =>
    $self->_ffi->zmq_send( $self->_socket_ptr, $msg, $len, $flags )
  );

  $self
}

sub send_multipart {
  my ($self, $parts, $flags) = @_;
  confess "Expected an ARRAY of message parts"
    unless Scalar::Util::reftype($parts) eq 'ARRAY'
    and @$parts;

  my @copy = @$parts;
  while (my $item = shift @copy) {
    $self->send( $item, @copy ? ZMQ_SNDMORE : $flags )
  }
}

sub recv {
  my ($self, $flags) = @_;
  $flags //= 0;

  my $zmsg_ptr = FFI::Raw::memptr(40);
  $self->throw_if_error( zmq_msg_init => 
    $self->_ffi->zmq_msg_init($zmsg_ptr) 
  );

  my $zmsg_len;
  $self->throw_if_error( zmq_msg_recv =>
    (
      $zmsg_len = $self->_ffi->zmq_msg_recv(
        $zmsg_ptr, $self->socket_ptr, $flags
      )
    )
  );

  my $ret;
  if ($zmsg_len) {
    my $data_ptr     = $self->_ffi->zmq_msg_data($zmsg_ptr);
    my $content_ptr  = FFI::Raw::memptr($zmsg_len);
    $self->_ffi->memcpy( $content_ptr, $data_ptr, $zmsg_len );
    $ret = $content_ptr->tostr($zmsg_len);
  } else {
    $ret = ''
  }

  $self->_ffi->zmq_msg_close($zmsg_ptr);

  $ret
}

sub recv_multipart {
  my ($self, $flags) = @_;

  my @parts = $self->recv($flags);
  push @parts, $self->recv($flags) while $self->get_sock_opt(ZMQ_RCVMORE);

  array(@parts)
}

sub has_event_pollin {
  my ($self) = @_;
  !! ( $self->get_sock_opt(ZMQ_EVENTS) & ZMQ_POLLIN )
}

sub has_event_pollout {
  my ($self) = @_;
  !! ( $self->get_sock_opt(ZMQ_EVENTS) & ZMQ_POLLOUT )
}

1;

=pod

=head1 NAME

POEx::ZMQ::FFI::Socket

=head1 SYNOPSIS

  # Used internally by POEx::ZMQ

=head1 DESCRIPTION

An object representing a ZeroMQ socket; used internally by L<POEx::ZMQ>.

This is essentially a minimalist reimplementation of Dylan Cali's L<ZMQ::FFI>;
see L<ZMQ::FFI> for a ZeroMQ FFI implementation intended for use outside
L<POE>.

=head2 ATTRIBUTES

=head2 METHODS

=head2 CONSUMES

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

Significant portions of this code are inspired by or derived from L<ZMQ::FFI>
by Dylan Calid (CPAN: CALID).

=cut

