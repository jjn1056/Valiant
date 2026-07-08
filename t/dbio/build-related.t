use Test::Most;
use Test::Needs 'DBIO', 'DBIO::SQLite';
use Test::Lib;
use TestDBIO
  -schema_class => 'SchemaIO::Nested';

# build_related / build_related_if_empty: related rows are built into the
# relationship cache for validation and form display but never inserted;
# the if_empty variant is a no-op when the cache is already populated; and
# the m2m form builds the whole join chain.

# --- build_related on a has_many ---

{
  my $parent = Schema->resultset('Parent')->new_result({ value => 'built parent' });

  ok my $child = $parent->build_related('children'), 'built a child';
  ok !$child->in_storage, 'child not inserted';
  is scalar(@{ $parent->children->get_cache||[] }), 1, 'child is in the cache';

  ok my $second = $parent->build_related('children'), 'built another child';
  is scalar(@{ $parent->children->get_cache||[] }), 2, 'builds append to the cache';
  is Schema->resultset('Child')->count, 0, 'nothing reached the database';
}

# --- build_related with attrs finds existing rows instead of duplicating ---

{
  my $parent = Schema->resultset('Parent')->create({
    value => 'saved parent',
    children => [ { value => 'aaaaa' } ],
  });
  ok $parent->valid, 'fixture valid';
  ok my $existing = Schema->resultset('Child')->search({ parent_id => $parent->id })->single,
    'fixture child in the database';

  is $parent->build_related('children', { id => $existing->id }), undef,
    'building an already-persisted related row returns nothing';

  ok my $built = $parent->build_related('children', { value => 'zzzzz' }),
    'built a new child from attrs';
  ok !$built->in_storage, 'not inserted';
  is $built->value, 'zzzzz', 'attrs applied';
  is Schema->resultset('Child')->search({ value => 'zzzzz' })->count, 0,
    'no zzzzz row in the database';
}

# --- build_related_if_empty ---

{
  my $parent = Schema->resultset('Parent')->new_result({ value => 'if empty parent' });

  ok my $child = $parent->build_related_if_empty('children'), 'builds when the cache is empty';
  is scalar(@{ $parent->children->get_cache||[] }), 1, 'one cached child';

  is $parent->build_related_if_empty('children'), undef, 'no-op when the cache is populated';
  is scalar(@{ $parent->children->get_cache||[] }), 1, 'cache size unchanged';
}

# --- build_related on a single (belongs_to) relation ---

{
  my $person = Schema->resultset('Person')->new_result({ username => 'builder' });

  ok my $state = $person->build_related('state'), 'built the single relation';
  ok !$state->in_storage, 'state not inserted';
  is scalar(@{ $person->related_resultset('state')->get_cache||[] }), 1, 'state cached';
  ok $person->state, 'relationship accessor sees the built result';
  is Schema->resultset('State')->count, 0, 'nothing reached the database';
}

# --- the m2m form builds the whole join chain ---

{
  my $person = Schema->resultset('Person')->new_result({ username => 'm2mbuilder' });

  ok my $role = $person->build_related_if_empty('roles'), 'built via the m2m name';
  ok $role->isa('SchemaIO::Nested::Result::Role'), 'returned the far side of the m2m';
  ok !$role->in_storage, 'role not inserted';

  my @person_roles = @{ $person->person_roles->get_cache||[] };
  is scalar(@person_roles), 1, 'the join row was built underneath';
  ok !$person_roles[0]->in_storage, 'join row not inserted';
  ok $person_roles[0]->role, 'the role hangs off the join row';

  is $person->build_related_if_empty('roles'), undef, 'no-op once the chain is populated';
  is scalar(@{ $person->person_roles->get_cache||[] }), 1, 'join cache unchanged';

  is Schema->resultset('PersonRole')->count, 0, 'no join rows in the database';
  is Schema->resultset('Role')->count, 0, 'no role rows in the database';
}

done_testing;
