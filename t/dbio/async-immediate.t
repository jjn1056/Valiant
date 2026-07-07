use Test::Most;
use Test::Needs 'DBIO', 'DBIO::SQLite';
use Test::Lib;
use TestDBIO
  -schema_class => 'SchemaIO::Create',
  -async => 'immediate';

# In 'immediate' mode every *_async runs the composed synchronous method
# and wraps the result -- so Valiant validation gating applies unchanged.

{
  # all NOT NULL columns supplied (so only validation, not a DB constraint,
  # can reject this) but username fails length[3,24] and password fails
  # length[8,24] per SchemaIO::Create::Result::Person's rules
  ok my $f = Schema->resultset('Person')->create_async({
    username => 'x', first_name => 'john', last_name => 'napiorkowski', password => 'short',
  }), 'create_async returns something';
  ok $f->is_ready, 'immediate mode future is already resolved';
  ok my $person = $f->get, 'future resolves to the row';
  ok $person->invalid, 'row is invalid';
  ok !$person->in_storage, 'invalid row was not inserted';
}

{
  # password confirmation is required on the create context (injected
  # password_confirmation attribute) -- payload mirrors t/dbic/create.t
  ok my $f = Schema->resultset('Person')->create_async({
    username => 'jjn', first_name => 'john', last_name => 'napiorkowski',
    password => 'hellohello', password_confirmation => 'hellohello',
  }), 'valid create_async';
  ok my $person = $f->get, 'future resolves';
  ok $person->valid, 'row is valid';
  ok $person->in_storage, 'valid row inserted';
}

done_testing;
