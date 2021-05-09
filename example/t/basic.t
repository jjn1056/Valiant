use Test::Most;
use DateTime;
use Test::DBIx::Class
  -schema_class => 'Example::Schema';

{
  ok my $rs =  Schema
    ->resultset('State')
    ->skip_validate;

  ok $rs->skip_validation;
  ok my $state = $rs->create({name=>'Texas', abbreviation=>'TX'});
  ok $state->skip_validation;
  ok $state->in_storage;
}

{
  ok my $state = Schema
    ->resultset('State')
    ->skip_validate
    ->create({name=>'New York', abbreviation=>'NY'});
  ok $state->in_storage;
}

{
  Schema->resultset('Role')
    ->populate([
        { label=>'user'},
        { label=>'admin'},
        { label=>'superuser'},
        { label=>'guest'},
      ]);

  my @rows = Schema->resultset('Role')->all;
  use Devel::Dwarn;
  Dwarn [ map  { +{id=>$_->id, label=>$_->label } } @rows];
}

# First bit, check 'registration'.

my $pid;

REGISTRATION: {
  FAIL_ALL_MISSING: {
    my %posted = ();
    my $person = Schema->resultset('Person')->new_result(\%posted);
    is_deeply +{$person->errors->to_hash(full_messages=>1)}, +{};
    $person->insert;
    is_deeply +{$person->errors->to_hash(full_messages=>1)}, +{
      first_name => [
        "First Name can't be blank",
        "First Name is too short (minimum is 2 characters)",
      ],
      last_name => [
        "Last Name can't be blank",
        "Last Name is too short (minimum is 2 characters)",
      ],
      password => [
        "Password can't be blank",
      ],
      username => [
        "Username can't be blank",
        "Username is too short (minimum is 3 characters)",
        "Username must contain only alphabetic and number characters",
      ],
    }, 'Got expected errors';
  }
  FAIL_SOME_MISSING: {
    my %posted = (
      first_name=>'John',
      password=>'abc123',
    );
    my $person = Schema->resultset('Person')->new_result(\%posted);
    is_deeply +{$person->errors->to_hash(full_messages=>1)}, +{};
    $person->insert;
    is_deeply +{$person->errors->to_hash(full_messages=>1)}, +{
      last_name => [
        "Last Name can't be blank",
        "Last Name is too short (minimum is 2 characters)",
      ],
      password_confirmation => [
        "Password Confirmation doesn't match 'Password'",
      ],
      username => [
        "Username can't be blank",
        "Username is too short (minimum is 3 characters)",
        "Username must contain only alphabetic and number characters",
      ],
    }, 'Got expected errors';
  }
  MORE_FAILS: {
    my %posted = (
      first_name=>'John',
      password=>'abc123',
      password_confirmation=>'123abc',
      username=>'jn',
    );
    my $person = Schema->resultset('Person')->new_result(\%posted);
    is_deeply +{$person->errors->to_hash(full_messages=>1)}, +{};
    $person->insert;
    is_deeply +{$person->errors->to_hash(full_messages=>1)}, +{
      last_name => [
        "Last Name can't be blank",
        "Last Name is too short (minimum is 2 characters)",
      ],
      password_confirmation => [
        "Password Confirmation doesn't match 'Password'",
      ],
      username => [
        "Username is too short (minimum is 3 characters)",
      ],
    }, 'Got expected errors';
  }
  PASS: {
    my %posted = (
      first_name=>'John',
      last_name=>'Napiorkowski',
      password=>'abc123',
      password_confirmation=>'abc123',
      username=>'jnn',
    );
    ok my $person = Schema->resultset('Person')->create(\%posted);
    ok $person->valid;
    ok $person->in_storage;
    ok defined($pid = $person->id);
  }
}

ok defined($pid);

# Profile testing

ok my $find = sub {
  my $params = shift;

  # Construct a person object with related bits preloaded.
  my $person = Schema->resultset('Person')->find(
    { 'me.id'=>$pid },
    { prefetch => ['profile', 'credit_cards', {person_roles => 'role' }] }
  );
  $person->build_related_if_empty('profile'); # We want to display a profile form object even if its not there.

  if($params) {
    $params->{roles} = [] unless exists $params->{roles}; # Handle the delete all case (this will eventually be handled by a params model)
    my $add = delete $params->{add};
    $person->context('profile')->update($params);
    $person->build_related('credit_cards') if $add->{credit_cards};
  }
  
  return $person;
};

BASIC: {
  my $person = $find->();
  is_deeply +{$person->errors->to_hash(full_messages=>1)}, +{};
}

ALL_MISSING: {
  my $person = $find->(+{ });
  is_deeply +{$person->errors->to_hash(full_messages=>1)}, +{
    credit_cards => [
      "Credit Cards has too few rows (minimum is 2)",
    ],
    person_roles => [
      "Person Roles has too few rows (minimum is 1)",
    ],
    profile => [
      "Profile Is Invalid",
    ],
    "profile.address" => [
      "Profile Address can't be blank",
      "Profile Address is too short (minimum is 2 characters)",
    ],
    "profile.birthday" => [
      "Profile Birthday doesn't look like a date",
    ],
    "profile.city" => [
      "Profile City can't be blank",
      "Profile City is too short (minimum is 2 characters)",
    ],
    "profile.phone_number" => [
      "Profile Phone Number can't be blank",
      "Profile Phone Number is too short (minimum is 10 characters)",
    ],
    "profile.state_id" => [
      "Profile State Id can't be blank",
    ],
    "profile.zip" => [
      "Profile Zip can't be blank",
      "Profile Zip is not a zip code",
    ],
  }, 'Got expected errors';
}

ERRORS_ONE: {
  my $person = $find->(+{
    first_name => "john",
    last_name => "nap",
    username => "j",
    profile => {
      address => "15604 Harry Lind Road",
      birthday => "200-02-13",
      city => "Elgin",
      id => 6,
      phone_number => "16467081837",
      state_id => 2,
      zip => 78621,
    },
    roles => [
      { id => 3 },
      { id => 4 },
    ],
  });

#is_deeply +{$person->errors->to_hash(full_messages=>1)}, +{
# });

  use Devel::Dwarn;
  Dwarn +{ $person->errors->to_hash(full_messages=>1) };
}


done_testing;

__END__

    use Devel::Dwarn;
    Dwarn +{ $person->errors->to_hash(full_messages=>1) };


    {
  credit_cards => {
    0 => {
      card_number => "3423423423423423",
      expiration => "2222-02-02",
      id => 16,
    },
    1 => {
      card_number => "53453454564564",
      expiration => "2222-02-02",
      id => 17,
    },
  },
  first_name => "john",
  last_name => "nap",
  profile => {
    address => "15604 Harry Lind Road",
    birthday => "2000-02-13",
    city => "Elgin",
    id => 6,
    phone_number => "16467081837",
    state_id => 2,
    zip => 78621,
  },
  roles => {
    2 => {
      id => 3,
    },
    3 => {
      id => 4,
    },
  },
  username => "jjn9",
}

