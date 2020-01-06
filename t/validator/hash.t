use Test::Most;

{
  package Local::Test::Person;

  use Moo;
  use Valiant::Validations;

  has name => (is=>'ro');
  has address => (is=>'ro');

  validates name => (
    length => [2,30],
    format => qr/[A-Za-z]+/, #yes no unicode names for this test...
  );

  validates address => (
    presence => 1,
    hash => [
      [street => presence => 1, length => [2,24] ],
      [city => presence => 1, length => [2,24] ],
      [zip => presence => 1, numericality => 'positive_integer', format => qr/\d\d\d\d\d/ ],
    ],
  );

  validates address => (
    presence => 1,
    hash => {
      validations => {
        street => [format => qr/[^\=]/, message => 'cannot have silly characters'],
        zip => [length => [5,5]],
      }
    }
  );
}

{
  my $person = Local::Test::Person->new(
    name => 'john',
    address => +{
      street => '15604 Harry Lind Road',
      city => 'Elgin',
      zip => '78621',
    },
  );

  ok $person->validate->valid;
}

{
  my $person = Local::Test::Person->new(
    name => '12',
    address => +{
      street => '=',
      city => 'Elgin',
      zip => '2aa',
    },
  );

  ok $person->validate->invalid;
  is_deeply +{ $person->errors->to_hash(full_messages=>1) },
    {
      'address' => {
                   'zip' => [
                              'Zip must be an integer',
                              'Zip does not match the required pattern',
                              'Zip is too short (minimum is 5 characters)'
                            ],
                   'street' => [
                                 'Street is too short (minimum is 2 characters)',
                                 'Street cannot have silly characters'
                               ]
                 },
      'name' => [
                'Name does not match the required pattern'
              ]
      };
}

done_testing;

