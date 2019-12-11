package Valiant::Validatable::Naming;

use Moo;
use String::CamelCase 'decamelize';

has 'object' => (
  is => 'ro',
  required => 1,
  weak_ref => 1,
);

has 'i18n_key' => (
  is => 'ro',
  required => 1,
  lazy => 1,
  init_arg => undef,
  default => sub {
    my $self = shift;
    my $class = ref $self;
    $class =~s/::/\//g;
    return decamelize $class;
    
  },
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
    return my $_human = ucfirst $name;
  },
);

sub human {
  my ($self, %options) = @_;
  return $self->_human unless $self->object->can('i18n_scope');
  die "Unimplemented";
  #TODO really handle translation lookup here.
  #see https://github.com/rails/rails/blob/66cabeda2c46c582d19738e1318be8d59584cc5b/activemodel/lib/active_model/naming.rb#L194
  #$self->object->translate($self->_human, \%options);
}


1;
