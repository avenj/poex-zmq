package POEx::ZMQ::FFI::Role::ErrorChecking;

use v5.10;
use Carp;
use strictures 1;

use POEx::ZMQ::FFI::Callable;
use POEx::ZMQ::FFI::Error;


use Moo::Role; use MooX::late;
requires 'soname';

has err_handler => (
  lazy    => 1,
  is      => 'ro',
  isa     => InstanceOf['POEx::ZMQ::FFI::Callable'],
  builder => sub {
    my $soname = shift->soname;
    POEx::ZMQ::FFI::Callable->new(
      zmq_errno => FFI::Raw->new(
        $soname, zmq_errno => FFI::Raw::int
      ),

      zmq_strerror => FFI::Raw->new(
        $soname, zmq_strerror =>
          FFI::Raw::str,  # <- errstr
          FFI::Raw::int,  # -> errno
      ),
    )
  },
);


sub errno {
  my ($self) = @_;
  $self->_err_handler->zmq_errno
}

sub errstr {
  my ($self, $errno) = @_;
  $self->_err_handler->zmq_strerror(
    $errno // $self->get_errno
  )
}

sub throw_zmq_error {
  my ($self, $call) = @_;
  my $errno  = $self->errno;
  my $errstr = $self->errstr;
  POEx::ZMQ::FFI::Error->new(
    message  => $errstr,
    errno    => $errno,
    function => $call,
  )->throw
}

sub throw_if_error {
  my ($self, $call, $rc) = @_;
  confess "Expected function name and return code"
    unless defined $call and defined $rc;

  if ($rc == -1) {
    $self->throw_zmq_error($call)
  }

  $self
}


1;
