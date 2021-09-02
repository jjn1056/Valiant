use v5.26;
use Object::Pad;
 
class OP::Person :repr(HASH)  {

  use Valiant::Validations;

  has $name :reader;
  has $age :reader;

  validates_with \&valid_person, test=>100, if => sub { my ($self, $options) = @_;  return 1  };
  validates_with \&is_nok;

  method valid_person($options) {
    $self->errors->add(name => 'Too Long', $options) if length($self->name) > 10;
    $self->errors->add(name => "Too Short $options->{test}", $options) if length($self->name) < 2; 
    $self->errors->add(age => 'Too Young', $options) if $self->age < 10; 
  }

  method is_nok {
    $self->errors->add(undef, 'Just Bad', +{ details=>'This always fails'});
  }
}
