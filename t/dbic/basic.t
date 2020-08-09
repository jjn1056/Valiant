use Test::Most;
use Test::Lib;
use Test::DBIx::Class
  -schema_class => 'Example::Schema';

{
  # Basic create test.
  ok my $person = Schema
    ->resultset('Person')
    ->create({
      __context => 'registration',
      username => 'jjn',
      first_name => 'john',
      last_name => 'napiorkowski',
      password => 'abc123',
    }), 'created fixture';

  ok $person->invalid, 'attempted record invalid';
  ok !$person->in_storage, 'record was not saved';

  is_deeply +{$person->errors->to_hash(full_messages=>1)}, +{
    password => [
      "Password is too short (minimum is 8 characters)",
    ],
    password_confirmation => [
      "Password Confirmation doesn't match 'Password'",
    ],
  }, 'Got expected errors';
}

{
  # Basic update test.
  ok my $person = Schema
    ->resultset('Person')
    ->create({
      username => 'jjn',
      first_name => 'john',
      last_name => 'napiorkowski',
      password => 'abc123aaaaaa',
    }), 'created fixture';

  ok $person->valid, 'attempted record valid';
  ok $person->in_storage, 'record was saved';

  $person->password('aaa');
  $person->update({last_name=>'1', __context => 'registration'});

  ok $person->invalid, 'attempted record invalid';

  is_deeply +{$person->errors->to_hash(full_messages=>1)}, +{
    last_name => [
      "Last Name is too short (minimum is 2 characters)",
    ],
    password => [
      "Password is too short (minimum is 8 characters)",
    ],
    password_confirmation => [
      "Password Confirmation doesn't match 'Password'",
    ],
  }, 'Got expected errors';

  $person->discard_changes;
  ok $person->password eq 'abc123aaaaaa', 'original not altered';
}

{
  # Basic multicreate test.
  ok my $person = Schema
    ->resultset('Person')
    ->create({
      __context => 'profile',
      username => 'jjn2',
      first_name => 'john',
      last_name => 'napiorkowski',
      password => 'abc123',
      profile => {
        zip => "asdasdå",
      }
    }), 'created fixture';

  ok $person->invalid, 'attempted record invalid';
  ok !$person->in_storage, 'record was not saved';

use Devel::Dwarn;
Dwarn +{ $person->errors->to_hash(full_messages=>1) };
}


#use Devel::Dwarn;
#Dwarn +{ $person->errors->to_hash(full_messages=>1) };

done_testing;
