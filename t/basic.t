use Test::Lib;
use Test::Most;
use Retiree;

ok my $retiree = Retiree->new(
  name=>'B',
  age=>4,
  retirement_date=>'2020');

use Devel::Dwarn;

#Dwarn [$retiree->validations];

$retiree->run_validations;

#Dwarn $retiree->errors;
Dwarn $retiree->errors->to_hash;
Dwarn $retiree->errors->size;
Dwarn [$retiree->errors('_base')];

#Dwarn(Valiant::I18N->dl);

warn Valiant::I18N->dl->localize('errors.messages.invalid');
warn Valiant::I18N->dl->localize('errors.messages.bad');

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
