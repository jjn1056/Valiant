use Test::Most;

{
  package Local::Test::Numericality;

  use Moo;
  use Valiant::Validations;
  use Valiant::I18N;

  has age => (is=>'ro');

  validates age => (
    numericality => {
      is_integer => 1,
      less_than => 200,
    },
  );

  validates age => (
    numericality => {
      is_integer => 1,
      greater_than_or_equal_to => 18,
    },
    on => 'voter',
  );

  validates age => (
    numericality => {
      is_integer => 1,
      greater_than_or_equal_to => 65,
    },
    on => 'retiree',
  );

  validates age => (
    numericality => {
      is_integer => 1,
      greater_than_or_equal_to => 100,
    },
    on => 'centarion',
  );
}

{
  ok my $object = Local::Test::Numericality->new(age=>1110);
  ok !$object->validate;
  is_deeply +{ $object->errors->to_hash(full_messages=>1) },
    {
      age => [
        "Age must be less than 200",
      ],
    };
}

{
  ok my $object = Local::Test::Numericality->new(age=>11);
  ok !$object->validate(context=>'voter');
  is_deeply +{ $object->errors->to_hash(full_messages=>1) },
    {
      age => [
        "Age must be greater than or equal to 18",
      ],
    };
}

{
  ok my $object = Local::Test::Numericality->new(age=>50);
  ok !$object->validate(context=>'centarion');
  is_deeply +{ $object->errors->to_hash(full_messages=>1) },
    {
      age => [
        "Age must be greater than or equal to 100",
      ],
    };
}

{
  ok my $object = Local::Test::Numericality->new(age=>11);
  ok !$object->validate(context=>['centarion', 'voter']);
  is_deeply +{ $object->errors->to_hash(full_messages=>1) },
    {
      age => [
        "Age must be greater than or equal to 18",
        "Age must be greater than or equal to 100",
      ],
    };
}

done_testing;
