package Valiant::Meta;

use Moo;
use Data::Perl qw/array/;

has validations => (
  is => 'ro',
  required => 1,
  init_arg => undef,
  default => sub { array() },
);

1;
