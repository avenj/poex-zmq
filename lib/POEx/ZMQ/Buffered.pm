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