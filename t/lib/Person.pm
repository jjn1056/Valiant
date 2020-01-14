package Person;

use Moo;
use Valiant::Validations;
use Valiant::I18N;

has 'name' => (is=>'ro',);
has 'age' => (is=>'ro');

validates_with \&valid_person, if => sub { my ($self, $options) = @_;  return $self->age ? 1:0  };
validates_with \&is_nok;

sub valid_person {
  my ($self) = @_;
  $self->errors->add(name => 'Too Long') if length($self->name) > 10;
  $self->errors->add(name => 'Too Short') if length($self->name) < 2; 
  $self->errors->add(age => 'Too Young') if $self->age < 10; 
}

sub is_nok {
  my ($self) = @_;
  $self->errors->add(_base => _t('bad'), +{ details=>'This always fails'});
}

1;
