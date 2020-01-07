use Test::Most;

{
  package Local::Test::Address;

  use Moo;
  use Valiant::Validations;

  has street => (is=>'ro');
  has city => (is=>'ro');
  has country => (is=>'ro');

  validates ['street', 'city'],
    presence => 1,
    length => [3, 40];

  validates 'country',
    presence => 1,
    inclusion => [qw/usa uk canada japan/];

  package Local::Test::Car;

  use Moo;
  use Valiant::Validations;

  has ['make', 'model', 'year'] => (is=>'ro');

  package Local::Test::Person;

  use Moo;
  use Valiant::Validations;

  has name => (is=>'ro');
  has address => (is=>'ro');
  has car => (is=>'ro');

  validates name => (
    length => [2,30],
    format => qr/[A-Za-z]+/, #yes no unicode names for this test...
  );

  validates address => (
    presence => 1,
    object => {
      validations => 1,
    }
  );

  validates car => (
    object => {
      for => 'Local::Test::Car',
      validations => [
        [ make => inclusion => [qw/Toyota Tesla Ford/] ],
        [ model => length => [2, 20] ],
        [ year => numericality => { greater_than_or_equal_to => 1960 } ],
      ],
      allow_blank => 1,
    },
  );
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

  ok $person->validate->valid;
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

  ok $person->validate->invalid;
  is_deeply +{ $person->errors->to_hash(full_messages=>1) },
    {
      'name' => [
        'Name does not match the required pattern'
      ],
      'address' => [{
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
      }]
    };
}

{
  my $address = Local::Test::Address->new(
    city => 'NY',
    country => 'Russia'
  );

  my $car = Local::Test::Car->new(
    make => 'Chevy',
    model => '1',
    year => 1900
  );

  my $person = Local::Test::Person->new(
    name => '12234',
    address => $address,
    car => $car,
  );


  ok $person->validate->invalid;
  is_deeply +{ $person->errors->to_hash(full_messages=>1) },
    {
      'car' => [{
           'model' => [
                        'Model is too short (minimum is 2 characters)'
                      ],
           'year' => [
                       'Year must be greater than or equal to 1960'
                     ],
           'make' => [
                       'Make is not in the list'
                     ]
               }],
      'address' => [{
               'street' => [
                             'Street can\'t be blank',
                             'Street is too short (minimum is 3 characters)'
                           ],
               'city' => [
                           'City is too short (minimum is 3 characters)'
                         ],
               'country' => [
                              'Country is not in the list'
                            ]
                   }],
      'name' => [
                  'Name does not match the required pattern'
                ]
    };
}

done_testing;
