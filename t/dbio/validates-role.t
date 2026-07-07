use Test::Most;
use Test::Needs 'DBIO', 'DBIO::SQLite';

{
  package Local::TestRow;

  use Moo;
  with 'DBIO::Valiant::Validates';

  has name => (is=>'ro');

  __PACKAGE__->validates(name => (presence => 1));
}

{
  my $obj = Local::TestRow->new(name => undef);
  is +($obj->default_validator_namespaces)[0], 'DBIO::Valiant::Validator',
    'DBIO validator namespace searched first';
  $obj->validate;
  ok $obj->errors->size, 'presence validation ran and failed';
}

{
  my $obj = Local::TestRow->new(name => undef);
  $obj->{__valiant_add} = 1;
  $obj->validate;
  is $obj->errors->size, 0, 'validate is a no-op for __valiant_add rows';
}

done_testing;
