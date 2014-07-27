use Test::More;
use strict; use warnings FATAL => 'all';

use POEx::ZMQ::FFI;

eval {; POEx::ZMQ::FFI->get_version };
if (my $err = $@) {
  if ($err =~ /requires.ZeroMQ/) {
    warn $err;
    die "OS unsupported";
  } else {
    die $@
  }
}

pass "System has acceptable ZMQ version";

done_testing
