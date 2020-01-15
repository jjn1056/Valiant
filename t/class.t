use Test::Most;
use Valiant::Class;

{
  package Local::Test::User;

  use Moo;

  has ['name', 'age', 'is_active'],
    is=>'ro',
    required=>1;
}

ok my $validator = Valiant::Class->new(
  for => 'Local::User',
  validations => [
    sub { unless($_[0]->is_active) { $_[0]->errors->add(_base=>'Cannot change inactive user') } },
    [ name => length => [2,15], format => qr/[a-zA-Z ]+/ ],
    [ age => numericality => 'positive_integer' ],
  ]
);

{
  ok my $user = Local::Test::User->new(name=>'John', age=>15, is_active=>1);
  ok my $result = $validator->validate($user);
  ok $result->valid;
}

{
  ok my $user = Local::Test::User->new(name=>'01', age=>-15, is_active=>0);
  ok my $result = $validator->validate($user);
  ok $result->invalid;
  is_deeply +{ $result->errors->to_hash(full_messages=>1) },
    {
      '_base' => [
                   'Cannot change inactive user'
                 ],
      'age' => [
                 'Age must be a positive integer'
               ],
      'name' => [
                  'Name does not match the required pattern'
                ] 
    };
}

done_testing;
