use Test::Most;

# So we create a base object and a role to make sure we can aggregate
# validation rules on the object in the expected manner (at least for
# Moo and probably Moose).

{
  package Person;

  use Moo;
  use Valiant::Validations;

  has 'name' => (is=>'ro');
  has 'age' => (is=>'ro');

  validate \&valid_person;
  validate \&is_nok;

  sub valid_person {
    my ($self) = @_;
    $self->errors->add(name => 'Too Long') if length($self->name) > 10;
    $self->errors->add(name => 'Too Short') if length($self->name) < 2; 
    $self->errors->add(age => 'Too Young') if $self->age < 10; 
  }

  sub is_nok {
    my ($self) = @_;
    $self->errors->add(base => 'Just Bad', +{ details=>'This always fails'});
  }

  package TestRole;

  use Moo::Role;
  use Valiant::Validations;

  validate sub {
    my ($self) = @_;
    $self->errors->add(base => 'Failed TestRole');
  };

  package Retiree;

  use Moo;
  use Valiant::Validations;

  extends 'Person';
  with 'TestRole';

  has 'retirement_date' => (is=>'ro');

  validate sub {
    my ($self) = @_;
    $self->errors->add(base => 'Failed Retiree');
  };

}

ok my $retiree = Retiree->new(
  name=>'B',
  age=>4,
  retirement_date=>'2020');

use Devel::Dwarn;

#Dwarn [$retiree->validations];

$retiree->run_validations;
Dwarn $retiree->errors;

Dwarn $retiree->errors->to_hash;
Dwarn $retiree->errors->size;

Dwarn $retiree->errors->{base};

done_testing;


__END__

  package MyValidator;

  use Moo;
  with 'Valiant::Validator';

  sub validate {
    my ($self, $object) = @_;
    $object->errors->add(name => 'Too Long') if length($object->name) > 10;
    $object->errors->add(name => 'Too Short') if length($object->name) < 2; 
    $object->errors->add(age => 'Too Young') if $object->age < 10; 
  }
