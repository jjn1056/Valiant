use Test::Most;
use Valiant::Object;

{
  package Local::Valiant::Test::Object;

  use Moo;
  with 'Valiant::Object';

  has name => (
    is => 'rw',
  );

  has age => (
    is => 'rw',
  );

  Local::Valiant::Test::Object->human_attribute_name(name => 'Person Name');
  Local::Valiant::Test::Object->human_attribute_name(age => 'Person Age');

  package Local::Valiant::Test::Object2;

  use Moo;
  extends 'Local::Valiant::Test::Object';

  Local::Valiant::Test::Object2->human_attribute_name(age => 'Age');

}

#is((Local::Valiant::Test::Object->human_attribute_name('name')), 'Person Name');
#is((Local::Valiant::Test::Object->human_attribute_name('age')), 'Person Age');

use Devel::Dwarn;

Dwarn +{ Local::Valiant::Test::Object->human_attribute_names };
Dwarn +{ Local::Valiant::Test::Object2->human_attribute_names };

ok 1;

done_testing;
