use Test::Most;

{
  package Local::Test::Address;

  use Moo;
  use Valiant::Validations;
  use Valiant::I18N;

  has street => (is=>'ro');
  has city => (is=>'ro');
  has country => (is=>'ro');

  validates ['street', 'city'],
    presence => 1,
    length => [3, 40];

  validates 'country',
    presence => 1,
    inclusion => [qw/usa uk canada japan/];

  package Local::Test::Person;

  use Moo;
  use Valiant::Validations;
  use Valiant::I18N;

  has name => (is=>'ro');
  has address => (is=>'ro');

  validates name => (
    length => [2,30],
    format => qr/[A-Za-z]+/, #yes no unicode names for this test...
  );

  validates address => (
    presence => 1,
    object => {
      validates => 1,
    }
  )
}

{
  my $address = Local::Test::Address->new(
    city => 'NYC',
    street => '15604 HL Drive',
    country => 'usa'
  );

  my $person = Local::Test::Person->new(
    name => 'john',
    address => $address,
  );

  ok $person->validate;
}

{
  my $address = Local::Test::Address->new(
    city => 'NY',
    country => 'Russia'
  );

  my $person = Local::Test::Person->new(
    name => '12234',
    address => $address,
  );

  ok !$person->validate;
  is_deeply +{ $person->errors->to_hash(full_messages=>1) },
    {
      'name' => [
        'Name does not match the required pattern'
      ],
      'address' => {
         'country' => [
                        'Country is not in the list'
                      ],
         'street' => [
                       'Street can\'t be blank',
                       'Street is too short (minimum is 3 characters)'
                     ],
         'city' => [
                     'City is too short (minimum is 3 characters)'
                   ]
      }
    };
}

done_testing;
