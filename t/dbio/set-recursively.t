use Test::Most;
use Test::Needs 'DBIO', 'DBIO::SQLite';
use Test::Lib;
use TestDBIO
  -schema_class => 'SchemaIO::Nested';

# ResultSet->set_recursively: hashref rows and DBIO::Row objects, with and
# without rollback_on_invalid, asserting on what actually reached the
# database rather than only the returned error objects.

sub wipe {
  Schema->resultset('One')->delete;
  Schema->resultset('OneOne')->delete;
}

sub db_count { Schema->resultset('OneOne')->count }

{
  # without rollback_on_invalid the valid rows persist and the invalid row
  # comes back carrying its errors
  ok my ($rs, @errs) = Schema->resultset('OneOne')->set_recursively([
    { value => 'first',  one => { value => 'one first' } },
    { value => 'second', one => { value => 'one second' } },
    { value => 'x',      one => { value => 'y' } },
  ]), 'set_recursively returned';

  is db_count(), 2, 'the two valid rows were written';
  is Schema->resultset('One')->count, 2, 'their nested rows were written';
  is scalar(@{ $rs->get_cache||[] }), 3, 'all three results cached on the resultset';

  is scalar(@errs), 1, 'one invalid result returned';
  ok $errs[0]->invalid, 'it is invalid';
  ok !$errs[0]->in_storage, 'it was not written';
  is_deeply [sort $errs[0]->errors->full_messages], [sort
    "Value is too short (minimum is 3 characters)",
    "One Is Invalid",
    "One Value is too short (minimum is 2 characters)",
  ], 'invalid row reports its own and its nested errors';
}

{
  # rollback_on_invalid: one bad row rolls back rows already written
  wipe();
  is db_count(), 0, 'clean slate';

  ok my ($rs, @errs) = Schema->resultset('OneOne')->set_recursively([
    { value => 'first',  one => { value => 'one first' } },
    { value => 'second', one => { value => 'one second' } },
    { value => 'x',      one => { value => 'y' } },
  ], { rollback_on_invalid => 1 }), 'set_recursively returned';

  is scalar(@errs), 1, 'one invalid result returned';
  is db_count(), 0, 'valid rows rolled back because the graph had an invalid row';
  is Schema->resultset('One')->count, 0, 'nested rows rolled back too';
}

{
  # rollback_on_invalid with an all-valid graph commits normally
  ok my ($rs, @errs) = Schema->resultset('OneOne')->set_recursively([
    { value => 'first',  one => { value => 'one first' } },
    { value => 'second', one => { value => 'one second' } },
  ], { rollback_on_invalid => 1 }), 'set_recursively returned';

  is scalar(@errs), 0, 'no errors';
  is db_count(), 2, 'all rows committed';
}

{
  # DBIO::Row objects are accepted alongside hashrefs
  wipe();

  my $good = Schema->resultset('OneOne')->new_result({
    value => 'row object', one => { value => 'nested row' },
  });
  my $bad  = Schema->resultset('OneOne')->new_result({
    value => 'x', one => { value => 'nested row two' },
  });

  ok my ($rs, @errs) = Schema->resultset('OneOne')->set_recursively([$good, $bad]),
    'set_recursively accepts row objects';

  ok $good->in_storage, 'valid row object inserted';
  is scalar(@errs), 1, 'invalid row object returned as an error';
  is $errs[0]->value, 'x', 'it is the row we passed in';
  is db_count(), 1, 'only the valid row reached the database';
}

{
  # anything else is refused
  throws_ok {
    Schema->resultset('OneOne')->set_recursively([ 'not a row' ]);
  } qr/Don't know how to handle row data/, 'unsupported row data dies';
}

done_testing;
