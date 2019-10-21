package Valiant::Meta;

use Moo;
use Data::Perl qw/array/;

has validations => (
  is => 'ro',
  required => 1,
  default => sub { array() },
);

1;
