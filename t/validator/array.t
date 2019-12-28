use Test::Most;

{
  package Local::Test::Array;

  use Moo;
  use Valiant::Validations;

  has status => (is=>'ro');

  validates status => (
    array => {
      max_length => 10,
      validates => [
        inclusion => +{
          in => [qw/active retired/],
        },
      ]
    },
  );
}

ok my $object = Local::Test::Array->new(
  status => [qw/active running retired retired aaa bbb ccc active/],
);

ok !$object->validate; # Returns false

warn $object->errors->_dump;


done_testing;

__END__

is_deeply +{ $object->errors->to_hash(full_messages=>1) },
  {
    'status' => [
                  'Status is not in the list'
                ],
    'type' => [
                'Type is not in the list'
              ]
  };


