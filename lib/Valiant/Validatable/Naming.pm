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
  init_arg => undef,
  default => sub {
    my $self = shift;
    my ($last) = reverse split '::', ref $self->object;
    return lc $last;
  },
);

has _human => (
  is => 'ro',
  required => 1,
  lazy => 1,
  init_arg => undef,
  default =>  sub {
    my $self = shift;
    my $name = $self->name;
    $name =~s/_/ /g;
    return my $human = ucfirst $name;
  },
);

sub human {
  my ($self, @options) = @_;
  $self->object->localize($self->_human, @options);
}


1;
