use Test::Most;

{
  package Local::Test::Format;

  use Moo;
  use Valiant::Validations;

  has phone => (is=>'ro');
  has name => (is=>'ro');

  validates phone => (
    format => +{
      match => qr/\d\d\d-\d\d\d-\d\d\d\d/,
    },
  );

  validates name => (
    format => +{
      without => qr/\d+/,
    },
  );

}

{
  ok my $object = Local::Test::Format->new(
    phone => '212-387-1212',
    name => 'john',
  );
  ok $object->validate->valid;
}

{
  ok my $object = Local::Test::Format->new(
    phone => '387-1212',
    name => 'jjn1056',
  );

  ok $object->validate->invalid;
  is_deeply +{ $object->errors->to_hash(full_messages=>1) },
    {
      'phone' => [
                 'Phone does not match the required pattern'
               ],
      'name' => [
                'Name contains invalid characters'
              ]
    };
}

done_testing;
