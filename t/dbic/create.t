use Test::Most;
use Test::Lib;
use Test::DBIx::Class
  -schema_class => 'Schema::Create';

{
  # Basic create test which also check the confirmation validation and
  # checks to make sure the default 'create' context works.

  ok my $person = Schema
    ->resultset('Person')
    ->create({
      username => '  jjn   ',
      first_name => 'john',
      last_name => 'napiorkowski',
      password => 'hello',
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

  # Ok now fix and try again

  $person->password('thisislongenough');
  $person->insert;

  ok $person->invalid, 'attempted record invalid';
  ok !$person->in_storage, 'record was not saved';

  is_deeply +{$person->errors->to_hash(full_messages=>1)}, +{
    password_confirmation => [
      "Password Confirmation doesn't match 'Password'",
    ],
  }, 'Got expected errors';

  # Finally fix it right

  $person->password('thisislongenough2');
  $person->password_confirmation('thisislongenough2');
  $person->insert;

  ok $person->valid, 'valid record';
  ok $person->in_storage, 'record was saved';

  # check the filter.   We need a ton of stand alone tests for this but this
  # is just a very basic test to make sure it compiles and appears to work.

  is $person->username, 'jjn', 'username got trim filter applied';

  # Given this record, show that basic update works.  even though these are
  # create oriented tests we want to test for edge cases like if someone does a
  # create and then holds that object to do updates later. I could see people
  # thinking that was a performance trick or doing it by mistake.

  $person->last_name('nap');
  $person->update;

  ok $person->valid, 'valid record';
  ok $person->in_storage, 'record was saved';

  # Flex the 'needs confirmation if changed' condition.   This is also testing
  # the default 'update' context that gets set when you do an update.  If you
  # check the Person class we are triggering a confirmation check on update only
  # if the password is actually changed.

  $person->password('thisislongenough3');
  $person->update;

  ok $person->invalid, 'attempted record invalid';
  ok $person->in_storage, 'record still in storage';
  ok $person->is_changed;

  is_deeply +{$person->errors->to_hash(full_messages=>1)}, +{
    password_confirmation => [
      "Password Confirmation doesn't match 'Password'",
    ],
  }, 'Got expected errors';

  $person->password_confirmation('thisislongenough3');
  $person->update;
  ok $person->valid, 'valid record';

  # Next check that the create relationship helpers also work as expected.  we only
  # need to check 'create_related' since all the others either proxy to it or we
  # don't need to auto validate (for example new_related we don't validate since
  # we don't validate automatically on new or new_result either.   If you call those
  # you need to run validate yourself (just like with ->new on Moo/se classes.).

  my $profile = $person->create_related('profile', {
  });

  ok $profile->invalid, 'invalid record';
  ok !$profile->in_storage, 'record wasnt saved';

  is_deeply +{$profile->errors->to_hash(full_messages=>1)}, +{
    "address",
    [
      "Address can't be blank",
      "Address is too short (minimum is 2 characters)",
    ],
    "city",
    [
      "City can't be blank",
      "City is too short (minimum is 2 characters)",
    ],
    "birthday",
    [
      "Birthday doesn't look like a date",
    ],
    "zip",
    [
      "Zip can't be blank",
      "Zip is not a zip code",
    ],
  }, 'Got expected errors';

  # Fix it

  $profile->address('15604 Harry Lind Road');
  $profile->city('Elgin');
  $profile->zip('78621');
  $profile->birthday('1991-01-23');
  $profile->update_or_insert;

  ok $profile->valid, 'valid record';
  ok $profile->in_storage, 'record was saved';
}

# For kicks lets test the uniqueness constraint in concert with
# the trim filter

{
  my $person = Schema
    ->resultset('Person')
    ->create({
      username => '     jjn ', # will be 'jjn' after trim
      first_name => 'john',
      last_name => 'napiorkowski',
      password => 'hellohello',
      password_confirmation => 'hellohello',
    }), 'created fixture';

  ok $person->invalid, 'attempted record invalid';
  ok !$person->in_storage, 'record was not saved';

  is_deeply +{$person->errors->to_hash(full_messages=>1)}, +{
    username => [
      'Username chosen is not unique',
    ],
  }, 'Got expected errors';

  # ok fix it

  $person->username('jjn2');
  $person->insert;

  ok $person->valid, 'valid record';
  ok $person->in_storage, 'record was saved';

  # Ok not try to update it to a username that is taken

  $person->username('jjn');
  $person->update;

  ok $person->invalid, 'attempted record invalid';

  is_deeply +{$person->errors->to_hash(full_messages=>1)}, +{
    username => [
      'Username chosen is not unique',
    ],
  }, 'Got expected errors';
}

# Some simple update tests.  We also test the password confirmation
# validation on update when changed.

{
  ok my $person = Schema
    ->resultset('Person')
    ->find({username=>'jjn'});

  $person->first_name('j');
  $person->update;

  is_deeply +{$person->errors->to_hash(full_messages=>1)}, +{
    first_name => [
      'First Name is too short (minimum is 2 characters)',
    ],
  }, 'Got expected errors';

  $person->first_name('jon');
  $person->password('abc');
  $person->update;

  is_deeply +{$person->errors->to_hash(full_messages=>1)}, +{
    password => [
      "Password is too short (minimum is 8 characters)",
    ],
    password_confirmation => [
      "Password Confirmation doesn't match 'Password'",
    ],
  }, 'Got expected errors';

  $person->password('abc124efg');
  $person->password_confirmation('abc124efg');
  $person->update;

  ok $person->valid, 'valid record';

  # Again for kicks and since we are here likes do a nestd update

  $person->last_name('n');
  $person->profile->zip('sadsdasdasdasdsdfsdfsdfsdf');
  $person->update;

  ok $person->invalid;

  is_deeply +{$person->errors->to_hash(full_messages=>1)}, +{
    "last_name",
    [
      "Last Name is too short (minimum is 2 characters)",
    ],
    "profile",
    [
      "Profile Is Invalid",
    ],
    "profile.zip",
    [
      "Profile Zip is not a zip code",
    ],
  }, 'Got expected errors';

  is_deeply +{$person->profile->errors->to_hash(full_messages=>1)}, +{
    "zip",
    [
      "Zip is not a zip code",
    ],
  }, 'Got expected errors';

  # Ok, try a deep update and expect it to work this time.

  $person->update({
    last_name => 'longenough',
    profile => {
      zip => '12345',
    }
  });

  ok $person->valid;
}

done_testing;

__END__

  use Devel::Dwarn;
  Dwarn $person->errors->to_hash(full_messages=>1);

