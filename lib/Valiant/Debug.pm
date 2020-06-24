package Valiant::Debug;

use strict;
use warnings FATAL => 'all';
use Exporter 5.57 qw(import);

our @EXPORT = qw($DEBUG);
our @EXPORT_OK = qw(VALIANT_DEBUG);

sub VALIANT_DEBUG { $ENV{VALIANT_DEBUG} ? 1:0 }

our $DEBUG = sub {
  my ($class, $level, @args) = @_;
  return unless VALIANT_DEBUG;
  warn "@args\n" if VALIANT_DEBUG == $level;
};

1;
