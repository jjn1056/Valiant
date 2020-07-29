use Test::Most;

{
  package Local::Test::Car;

  use Moo;
  use Valiant::Validations;

  has ['make', 'model', 'year'] => (is=>'ro');

  validates make => ( allow_blank => 1, inclusion => [qw/Toyota Tesla Ford/] );
  validates model => ( allow_blank => 1, length => [2, 20] );
  validates year => ( allow_blank => 1, numericality => { greater_than_or_equal_to => 1960 });

  package Local::Test::Array;

  use Moo;
  use Valiant::Validations;

  has status => (is=>'ro');
  has name => (is=>'ro');
  has car => (is=>'ro');

  validates name => (length=>[2,5]);
  validates car => ( array => { validations => [object=>1] } );
  validates status => (
    array => {
      max_length => 3,
      min_length => 1,
      validations => [
        inclusion => +{
          in => [qw/active retired/],
        },
      ]
    },
  );
}

ok  my $car = Local::Test::Car->new(
    make => 'Chevy',
    model => '1',
    year => 1900
  );


ok my $object = Local::Test::Array->new(
  name => 'napiorkowski',
  status => [qw/active running retired retired aaa bbb ccc active/],
  car => [$car],
);

ok $object->validate->invalid; 
ok $object->car->[0]->invalid; 


is_deeply +{$object->car->[0]->errors->to_hash(full_messages=>1)},
{
  make => [
    "Make is not in the list",
  ],
  model => [
    "Model is too short (minimum is 2 characters)",
  ],
  year => [
    "Year must be greater than or equal to 1960",
  ],
};

is_deeply +{ $object->errors->to_hash(full_messages=>1) },
{
  car => [
    "Car Is Invalid",
  ],
  "car.0" => [
    "Car 0 Is Invalid",
  ],
  "car.0.make" => [
    "Car 0 Make is not in the list",
  ],
  "car.0.model" => [
    "Car 0 Model is too short (minimum is 2 characters)",
  ],
  "car.0.year" => [
    "Car 0 Year must be greater than or equal to 1960",
  ],
  name => [
    "Name is too long (maximum is 5 characters)",
  ],
  status => [
    "Status Is Invalid",
  ],
  "status.1" => [
    "Status 1 is not in the list",
  ],
  "status.4" => [
    "Status 4 is not in the list",
  ],
  "status.5" => [
    "Status 5 is not in the list",
  ],
  "status.6" => [
    "Status 6 is not in the list",
  ],
};

done_testing;

__END__



