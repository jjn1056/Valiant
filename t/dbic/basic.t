use Test::Most;
use Test::Lib;
use Test::DBIx::Class
  -schema_class => 'Example::Schema';

ok my $state = Schema
  ->resultset('State')
  ->create({name=>'Texas', abbreviation=>'TX'});
ok $state->valid;
ok $state->id;

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
      __context => ['registration'],
      username => 'jjn',
      first_name => 'john',
      last_name => 'napiorkowski',
      password => 'abc123aaaaaa',
      password_confirmation => 'abc123aaaaaa',
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

  # Make sure real updates are not blocked
  $person->password('890xyzgreen59');
  $person->password_confirmation('890xyzgreen59');

  $person->update({ __context => 'registration'});

  ok $person->valid, 'attempted record valid';
  ok $person->in_storage, 'saved';

  # This is maybe a TODO since DBIC won't pass the non field confirmation via
  # update args
  #$person->password('890xyzgreen59123');
  #$person->update({
  #    password_confirmation => '890xyzgreen59123', 
  #    __context => 'registration'
  #});

  #ok $person->valid, 'attempted record valid';
  #ok $person->in_storage, 'saved';
}

{
  # Basic multicreate test. (might have /has one)
  ok my $person = Schema
    ->resultset('Person')
    ->create({
      __context => ['registration','profile'],
      username => 'jjn2',
      first_name => 'john',
      last_name => 'napiorkowski',
      password => 'abc123',
      password_confirmation => 'abc123',
      profile => {
        zip => "78621",
        city => 'Elgin',
      },
      credit_cards => [
        {card_number=>'asdasd', expiration=>'ddw'},
      ],
    }), 'created fixture';

  ok $person->invalid, 'attempted record invalid';
  ok !$person->in_storage, 'record was not saved';
  is_deeply +{$person->errors->to_hash(full_messages=>1)}, +{
    credit_cards => [
      "Credit Cards Is Invalid",
      "Credit Cards has too few rows (minimum is 2)",
    ],
    password => [
      "Password is too short (minimum is 8 characters)",
    ],
    profile => [
      "Profile Is Invalid",
    ],
  }, 'Got expected errors';

  ok $person->profile->invalid, 'attempted profile was invalid';
  ok !$person->profile->in_storage, 'record was not saved';
  is_deeply +{$person->profile->errors->to_hash(full_messages=>1)}, +{
    address => [
      "Address can't be blank",
      "Address is too short (minimum is 2 characters)",
    ],
    birthday => [
      "Birthday doesn't look like a date",
    ],
    phone_number => [
      "Phone Number can't be blank",
      "Phone Number is too short (minimum is 10 characters)",
    ],
    state_id => [
      "State Id can't be blank",
    ],
  }, 'Got expected errors';

  ok $person->credit_cards->first->invalid, 'attempted profile was invalid';
  ok !$person->credit_cards->first->in_storage, 'record was not saved';
  is_deeply +{$person->credit_cards->first->errors->to_hash(full_messages=>1)}, +{
    card_number => [
      "Card Number is too short (minimum is 13 characters)",
      "Card Number does not look like a credit card",
    ],
    expiration => [
      "Expiration does not look like a datetime value",
    ],
  }, 'Got expected errors';

  # Ok not do a 'good' one with no errors and lets make sure it all
  # get stuck in the DB correctly.
  ok my $person_correct = Schema
    ->resultset('Person')
    ->create({
      __context => ['registration','profile'],
      username => 'jjn3',
      first_name => 'john',
      last_name => 'napiorkowski',
      password => 'abc123rrrrrr',
      password_confirmation => 'abc123rrrrrr',
      profile => {
        zip => "78621",
        city => 'Elgin',
        address => '15604 Harry Lind Road',
        birthday => '1991-01-23',
        phone_number => '2123879509',
        state_id => $state->id,
      },
      credit_cards => [
        {card_number=>'11111222223333344444', expiration=>'2100-01-01'},
        {card_number=>'11111222223333555555', expiration=>'2101-01-01'},
      ],
    }), 'created fixture';

  ok $person_correct->valid, 'attempted record valid';
  ok $person_correct->in_storage, 'record was saved';
  ok $person_correct->profile->valid, 'attempted profile was valid';
  ok $person_correct->profile->in_storage, 'record was saved';

  ok my @credit_cards = $person_correct->credit_cards->all;
  is scalar(@credit_cards), '2', 'correct number of rows';
  ok $credit_cards[0]->valid, 'attempted profile was valid';
  ok $credit_cards[0]->in_storage, 'record was saved';
  ok $credit_cards[1]->valid, 'attempted profile was valid';
  ok $credit_cards[1]->in_storage, 'record was saved';
}

{
  # Test mulicreate with objects
  # What happens when you try to add a related object that

  ok my $profile = Schema
    ->resultset('Profile')
    ->new_result({
      zip => "78621",
      city => 'Elgin',
      address => '15604 Harry Lind Road',
      birthday => '1991-01-23',
      phone_number => '2123879509',
      state_id => $state->id,
    }), 'created profile';

  ok $profile->valid, 'attempted profile was valid';
  ok ! $profile->in_storage, 'record has not been saved';

  ok my $cc_1 = Schema
    ->resultset('CreditCard')
    ->new_result({
      card_number => '11111222223333344444',
      expiration => '2100-01-01'
    }), 'created credit card one';

  ok $cc_1->valid, 'attempted cc was valid';
  ok ! $cc_1->in_storage, 'record has not been saved';

  ok my $cc_2 = Schema
    ->resultset('CreditCard')
    ->new_result({
      card_number => '1111122222333334466',
      expiration => '2200-01-01'
    }), 'created credit card two';

  ok my $cc_invalid = Schema
    ->resultset('CreditCard')
    ->new_result({
      card_number => '1111122222333334466',
      expiration => '1200-01-01'
    }), 'created credit card two';


  ok $cc_2->valid, 'attempted cc was valid';
  ok ! $cc_2->in_storage, 'record has not been saved';

  ok my $person_correct = Schema
    ->resultset('Person')
    ->create({
      __context => ['registration','profile'],
      username => 'jjn4',
      first_name => 'john',
      last_name => 'napiorkowski',
      password => 'abc123rrrrrr',
      password_confirmation => 'abc123rrrrrr',
      profile => $profile,
      credit_cards => [ $cc_1, $cc_2 ],
    }), 'created person';

  ok $person_correct->valid, 'attempted record was valid';
  ok $person_correct->in_storage, 'record has been saved';

  ok my $person_invalid = Schema
    ->resultset('Person')
    ->create({
      __context => ['registration','profile'],
      username => 'jjn4',
      first_name => 'john',
      last_name => 'napiorkowski',
      password => 'abc123rrrrrr',
      password_confirmation => 'abc123rrrrrr',
      profile => $profile,
      credit_cards => [ $cc_1, $cc_invalid ],
    }), 'created person';

  ok $person_invalid->invalid, 'attempted record was valid';
  ok ! $person_invalid->in_storage, 'record has not been saved';
  is_deeply +{$person_invalid->errors->to_hash(full_messages=>1)}, +{
    credit_cards => [
      "Credit Cards Is Invalid",
    ],
    username => [
      "Username chosen is not unique",
    ],
  }, 'Got expected errors';

  ok my @credit_cards = $person_invalid->credit_cards->all;
  is_deeply +{$credit_cards[1]->errors->to_hash(full_messages=>1)}, +{
    expiration => [
      "Expiration must be in the future",
    ],
  }, 'Got expected errors';
}

{
  # update deeply
  ok my $person = Schema
    ->resultset('Person')
    ->create({
      __context => ['registration'],
      username => 'jjn5',
      first_name => 'john',
      last_name => 'napiorkowski',
      password => 'abc123aaaaaa',
      password_confirmation => 'abc123aaaaaa',
    }), 'created fixture';

  ok $person->valid, 'attempted record valid';
  ok $person->in_storage, 'record was saved';

  $person->update({
    __context => ['registration','profile'],
    last_name => 'a',
    profile => {
      birthday => '2991-01-23',
      zip => '78621',
    },
  });

  ok $person->invalid, 'attempted record was invalid';
  ok $person->is_changed, 'record has unsaved changes';
  is $person->last_name, 'a', 'got correct last_name';
  
  is_deeply +{$person->errors->to_hash(full_messages=>1)}, +{
    last_name => [
      "Last Name is too short (minimum is 2 characters)",
    ],
    profile => [
      "Profile Is Invalid",
    ],
  };

  ok $person->profile->invalid, 'attempted record was invalid';
  ok ! $person->profile->in_storage, 'record not yet stored';

  is_deeply +{$person->profile->errors->to_hash(full_messages=>1)}, +{
    address => [
      "Address can't be blank",
      "Address is too short (minimum is 2 characters)",
    ],
    birthday => [
      "Birthday chosen date can't be later than 2020-08-19",
    ],
    city => [
      "City can't be blank",
      "City is too short (minimum is 2 characters)",
    ],
    phone_number => [
      "Phone Number can't be blank",
      "Phone Number is too short (minimum is 10 characters)",
    ],
    state_id => [
      "State Id can't be blank",
    ],
  }, 'Got expected errors';

  $person->update({
    __context => ['registration','profile'],
    last_name => 'abcdefghi',
    profile => {
      zip => "78621",
      city => 'Elgin',
      address => '15604 Harry Lind Road',
      birthday => '1991-01-23',
      phone_number => '2123879509',
      state_id => $state->id,
    },
  });

  ok $person->valid, 'attempted record was valid';
  ok ! $person->is_changed, 'record has no unsaved changes';
  ok $person->in_storage, 'record stored';

  ok $person->profile->valid;
  is $person->profile->city, 'Elgin';
  ok $person->profile->in_storage, 'Profile stored';

}

done_testing;

__END__


