package GlobalOptions;

use Moo;
use Valiant::Validations;
use Valiant::I18N;

has 'name' => (
  is => 'ro',
);

validates 'name' => (
  length => {
    in => [2,11],
    if => sub {
      my ($self) = @_;
      warn 22222; 1;
    },
  },
  with => {
    cb => sub {
      my ($self, $attr) = @_;
      $self->errors->add($attr, 'failed');
    },
    if => sub {
      my ($self) = @_;
      warn 333; 1;
    },

  },
  if => sub { warn 111; 1 },
);

1;
