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



done_testing;

__END__

    use Devel::Dwarn;
    Dwarn +{ $person->errors->to_hash(full_messages=>1) };

