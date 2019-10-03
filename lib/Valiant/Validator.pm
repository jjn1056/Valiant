package Valiant::Validator;

use Moo::Role;
use String::CamelCase;

requires 'validate';

has name => (
  is => 'ro',
  init_arg => undef,
  lazy => 1,
  required => 1,
  builder => '_build_name',
);

sub _build_name {
  my $class = ref($_[0]);
  my ($name_proto) = reverse(split('::', $class));
  return lc String::CamelCase::decamelize($name_proto);
}

1;
