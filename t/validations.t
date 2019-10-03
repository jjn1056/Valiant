use Test::Most;

ok 1;

{
  package MyValidator;

  use Moo;
  with 'Valiant::Validator';

  sub validate {
    my ($self, $object) = @_;
    $object->errors->add(name => 'Too Long') if length($object->name) > 10;
    $object->errors->add(name => 'Too Short') if length($object->name) < 2; 
    $object->errors->add(age => 'Too Young') if $object->age < 10; 
  }
  
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
    $self->errors->add(base => 'Just Bad');
  }

  package TestRole;

  use Moo::Role;
  use Valiant::Validations;

  validate sub { 222 };

  package Retiree;

  use Moo;
  use Valiant::Validations;

  extends 'Person';
  with 'TestRole';

  has 'retirement_date' => (is=>'ro');

  validate sub { 111 };

}

ok my $person = Person->new(name=>'A', age=>9);

use Devel::Dwarn;
Dwarn $person->validations;

ok my $retiree = Retiree->new(name=>'B', age=>70, retirement_date=>'2020');

Dwarn $retiree->validations;

Dwarn keys %{$Role::Tiny::APPLIED_TO{'Retiree'}};

done_testing;
