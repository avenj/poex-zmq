package POEx::ZMQ::Buffered;

use Carp;
use strictures 1;

use List::Objects::Types  -types;
use Types::Standard       -types;

use Moo; use MooX::late;


has item => (
  required  => 1,
  is        => 'ro',
);

has item_type => (
  required  => 1,
  is        => 'ro',
  isa       => Enum[qw/single multipart/],
);

has flags => (
  lazy      => 1,
  is        => 'ro',
  predicate => 1,
  builder   => sub { undef },
);

1;


=pod

=head1 NAME

POEx::ZMQ::Buffered

=head1 SYNOPSIS

  # Used internally by POEx::ZMQ

=head1 DESCRIPTION

A buffered outgoing single or multipart message.

See L<POEx::ZMQ> & L<POEx::ZMQ::Socket>.

=head2 ATTRIBUTES

=head3 item

The (possibly filtered; see L<POEx::ZMQ::Socket>) message body.

=head3 item_type

The message type -- C<single> or C<multipart>.

=head3 flags

The ZeroMQ message flags.

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
