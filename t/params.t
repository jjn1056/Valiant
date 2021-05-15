use Test::Most;

{
  package Local::Person;

  use Moo;
  use Valiant::Params;

  has [qw/name age email phone/] => (is=>'ro');

  # If param is named then the incoming is permitted to have that value.  It can be option (if you want required set that on the attribute)
  param 'name',
    name => 'name', # default is use the attribute name
    multi => 1; # this is the default.   it means will allow scalar only.   if 1 then forces to arrayref (or acceptsref)

  param [qw/age email phone/]; # This form allows no options.
}

my $person = Local::Person->new(
  request => +{name=>'john', email=>'jjn1056@gmail.com'},
  age => 11,
);

use Devel::Dwarn;
Dwarn +{ $person->params_info };
Dwarn $person;

done_testing;
