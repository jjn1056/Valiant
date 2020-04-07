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
    with => sub {
      my ($self, $attribute_name, $value, $opts) = @_;
      $self->errors->add($attribute_name, 'Always Bad', $opts) if $self->errors->size;
    },
    hash => {
      validations => {
        street => [format => qr/[^\=]/, message => 'cannot have silly characters'],
        zip => [length => [5,5]],
      },
    },
    with => sub {
      my ($self, $attribute_name, $value, $opts) = @_;
      $self->errors->add($attribute_name, 'Bad Address', $opts) if $self->errors->size;
    },
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
        address => [
          {
            street => [
              "Street is too short (minimum is 2 characters)",
              "Street cannot have silly characters",
            ],
            zip => [
              "Zip must be a positive integer",
              "Zip does not match the required pattern",
              "Zip is too short (minimum is 5 characters)",
            ],
          },
          "Address Always Bad",
          "Address Bad Address",
        ],
        'name' => [
                'Name does not match the required pattern'
              ]
      };

      #use Devel::Dwarn;
      #Dwarn +{ $person->errors->to_hash(full_messages=>1) };
}

done_testing;

