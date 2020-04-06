{
  package Local::A;

  use Moo;
  
  with 'Valiant::Validations';

  has age => (is=>'ro');
  has equals => (is=>'ro', default=>33);

  __PACKAGE__->validates(age => (
    numericality => {
      only_integer => 1,
      less_than => 200,
      less_than_or_equal_to => 199,
      greater_than => 10,
      greater_than_or_equal_to => 9,
      equal_to => \&equals,
    },
  ));

  __PACKAGE__->validates(equals => (numericality => [5,100]));
}

use Test::Most;

ok my $a = Local::A->new;
ok $a->invalid;

use Devel::Dwarn;
#Dwarn $a->errors->to_hash;

{
  package Local::B;

  use Moo;
  use Valiant::Exports;

  has age => (is=>'ro');
  has equals => (is=>'ro', default=>33);

  validates age => (
    numericality => {
      only_integer => 1,
      less_than => 200,
      less_than_or_equal_to => 199,
      greater_than => 10,
      greater_than_or_equal_to => 9,
      equal_to => \&equals,
    },
  );

  validates equals => (numericality => [5,100]);
}

{
  ok my $object = Local::B->new(age=>1110);
  ok $object->validate->invalid;
  is_deeply +{ $object->errors->to_hash(full_messages=>1) },
    {
      age => [
        "Age must be equal to 33",
        "Age must be less than 200",
        "Age must be less than or equal to 199",
      ],
    };
}

done_testing;
