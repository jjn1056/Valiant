use Test::Most;

{
  package Local::Test::Array;

  use Moo;
  use Valiant::Validations;

  has status => (is=>'ro');
  has name => (is=>'ro');

  validates name => (length=>[2,5]);
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

ok my $object = Local::Test::Array->new(
  name => 'napiorkowski',
  status => [qw/active running retired retired aaa bbb ccc active/],
);

ok $object->validate->invalid; 

# for now...
is_deeply +{ $object->errors->to_hash(full_messages=>1) },
  {
          'status.1' => [
                          'Status.1 is not in the list'
                        ],
          'status.5' => [
                          'Status.5 is not in the list'
                        ],
          'status.4' => [
                          'Status.4 is not in the list'
                        ],
          'status.6' => [
                          'Status.6 is not in the list'
                        ] 
    };

warn $object->errors->_dump;


done_testing;

__END__



