package POEx::ZMQ::FFI::Context;

use Carp;
use strictures 1;

use FFI::Raw;

use POEx::ZMQ::FFI::Callable;

use Types::Standard -types;


use Moo; use MooX::late;


has soname => (
  required  => 1,
  is        => 'ro',  
);

has threads => (
  lazy      => 1,
  is        => 'ro',
  isa       => Int,
  builder   => sub { 1 },
);

has max_sockets => (
  lazy      => 1,
  is        => 'ro',
  isa       => Int,
  builder   => sub { 1024 },
);


# FIXME create a generic 'ffi' obj,
#       something to give us convenient AUTOLOAD access to
#       underlying FFI::Raw objs
has _ffi => ( 
  lazy      => 1,
  is        => 'ro',
  isa       => InstanceOf['POEx::ZMQ::FFI::Callable'],
  builder   => sub {
    my $soname = shift->soname;
    POEx::ZMQ::FFI::Callable->new(
      zmq_ctx_new => FFI::Raw->new(
        $soname, zmq_ctx_new => 
          FFI::Raw::ptr,   # <- ctx ptr
      ),

      zmq_ctx_set => FFI::Raw->new(
        $soname, zmq_ctx_set =>
          FFI::Raw::int,   # <- rc
          FFI::Raw::ptr,   # -> ctx ptr
          FFI::Raw::int,   # -> opt (constant)
          FFI::Raw::int,    # -> opt value
      ),

      zmq_ctx_get => FFI::Raw->new(
        $soname, zmq_ctx_get =>
          FFI::Raw::int,  # <- opt value
          FFI::Raw::ptr,  # -> ctx ptr
          FFI::Raw::int,  # -> opt (constant)
      ),

      zmq_ctx_destroy => FFI::Raw->new(
        $soname, zmq_ctx_destroy =>
          FFI::Raw::int,  # <- rc
          FFI::Raw::ptr,  # -> ctx ptr
      ),
    )
  },
);


has _ctx_ptr => (
  lazy      => 1,
  is        => 'ro',
  builder   => sub { -1 },
);


sub BUILD {
  # FIXME set up approp context opts
}

sub DEMOLISH {
  my ($self) = @_;
  $self->destroy_ctx unless $self->_ctx_ptr == -1;
}


sub destroy_ctx {

}

sub create_socket {

}

sub get_ctx_opt {

}

sub set_ctx_opt {

}


1;
