package Valiant::Validatable::Naming;

use Moo;

has 'object' => (
  is => 'ro',
  required => 1,
  weak_ref => 1,
);

has name => (
  is => 'ro',
  required => 1,
  lazy => 1,
  default => sub {
    my $self = shift;

  },
);

1;
