package POEx::ZMQ;

use Carp;
use strictures 1;

use POEx::ZMQ::FFI::Context;

use POEx::ZMQ::Constants ();
use POEx::ZMQ::Socket ();

=for Pod::Coverage import

=cut

sub import {
  my $pkg = caller;
  POEx::ZMQ::Constants->import::into($pkg, '-all');
}

sub context { shift; POEx::ZMQ::FFI::Context->new(@_) }

1;


=pod

=head1 NAME

POEx::ZMQ - Asynchronous ZeroMQ sockets for POE

=head1 SYNOPSIS

  # An example ZMQ_ROUTER socket ->
  use POE;
  use POEx::ZMQ;

  POE::Session->create(
    inline_states => +{
      _start => sub {
        # Set up a ROUTER; save our Context for creating other sockets later:
        $_[HEAP]->{ctx} = POEx::ZMQ->context;

        $_[HEAP]->{rtr} = POEx::ZMQ::Socket->new(
          context => $_[HEAP]->{ctx},
          type    => ZMQ_ROUTER,
        );

        $_[HEAP]->{rtr}->start;

        $_[HEAP]->{rtr}->bind( 'tcp://127.0.0.1:1234' );
      },

      zmq_recv_multipart => sub {
        # ROUTER got message from REQ; sender identity is prefixed,
        # parts are available as a List::Objects::WithUtils::Array ->
        my $parts = $_[ARG0];
        my ($id, undef, $content) = $parts->all;

        my $response;
        # ...

        $_[KERNEL]->post( $_[SENDER], send_multipart =>
          $id, '', $response
        );
      },
    },
  );

  POE::Kernel->run;

=head1 DESCRIPTION

A L<POE> component providing non-blocking L<http://www.zeromq.org|ZeroMQ>
(versions 3.x & 4.x) integration.

See L<POEx::ZMQ::Socket> for details on using sockets.

Each ZeroMQ socket is an event emitter powered by L<MooX::Role::POE::Emitter>;
the documentation for that distribution is likely to be helpful.

B<This is early-development software,> as indicated by the C<0.x> version number.
The test suite is incomplete, bugs are sure to be lurking, documentation is
not yet especially verbose, and the API is not completely guaranteed.  Issues
& pull requests are welcome, of course:
L<http://www.github.com/avenj/poex-zmq>

If you are not using L<POE>, try L<ZMQ::FFI> for an excellent loop-agnostic
ZeroMQ implementation.

=head2 import 

Importing this package brings in the full set of L<POEx::ZMQ::Constants>, and
ensures L<POEx::ZMQ::Socket> is loaded.

=head3 context

  my $ctx = POEx::ZMQ->context(max_sockets => 512);

Returns a new L<POEx::ZMQ::FFI::Context>. C<@_> is passed through.

The context object should be shared between sockets belonging to the same
process; a forked child process should create a new context with its own set
of sockets.

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

Significant portions of the L<POEx::ZMQ::FFI> backend are inspired by or
derived from L<ZMQ::FFI> (version 0.14) by Dylan Cali (CPAN: CALID).

Licensed under the same terms as Perl.

=cut
