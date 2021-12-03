use Test::Most;
use Test::Lib;
use DateTime;
use Valiant::Util::Formbuilder ':all';
use Test::DBIx::Class
  -schema_class => 'Example::Schema';

ok my $state = Schema
  ->resultset('State')
  ->create({name=>'Texas', abbreviation=>'TX'});
ok $state->valid;
ok $state->id;


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



warn form_for($person, sub {
  my $fb = shift;
  use Devel::Dwarn;
  Dwarn $fb;
  text_area_tag "user", "hello", +{ class=>['111', 'aaa'] };

});

done_testing;

__END__


