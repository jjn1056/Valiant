use Test::Most;
use Test::Needs 'DBIO', 'DBIO::SQLite';
use Test::Lib;
use TestDBIO
  -schema_class => 'SchemaIO::Nested';

# The pseudo params understood by set_from_params_recursively: _delete
# (scalar and HTML-checkbox array forms), _add, _nop, _restore and _action,
# plus the child-pruning bookkeeping (is_pruned / is_removed) when an
# existing nested row is dropped.

sub make_parent {
  my @child_values = @_;
  my $parent = Schema->resultset('Parent')->create({
    value => 'parent value',
    children => [ map { +{ value => $_ } } @child_values ],
  });
  die "fixture invalid" unless $parent->valid;
  return Schema->resultset('Parent')->find({ 'me.id' => $parent->id }, { prefetch => 'children' });
}

sub child_by_value {
  my ($parent, $value) = @_;
  my ($child) = grep { $_->value eq $value } @{ $parent->children->get_cache||[] };
  return $child;
}

# --- _delete scalar forms ---

{
  my $parent = make_parent('aaaaa', 'bbbbb');
  my $doomed = child_by_value($parent, 'bbbbb');

  $parent->update({ children => [
    { id => child_by_value($parent, 'aaaaa')->id, value => 'aaaaa' },
    { id => $doomed->id, _delete => 1 },
  ]});

  ok $parent->valid, 'update valid';
  ok $doomed->is_marked_for_deletion, '_delete => 1 marked the row';
  ok $doomed->is_removed, 'marked row reports is_removed';
  is $parent->children->count, 1, 'marked row deleted from the database';
  ok !Schema->resultset('Child')->find($doomed->id), 'row really gone';
}

{
  my $parent = make_parent('aaaaa', 'bbbbb');
  my $spared = child_by_value($parent, 'bbbbb');

  $parent->update({ children => [
    { id => child_by_value($parent, 'aaaaa')->id, value => 'aaaaa' },
    { id => $spared->id, _delete => 0 },
  ]});

  ok $parent->valid, 'update valid';
  ok !$spared->is_marked_for_deletion, '_delete => 0 does not mark the row';
  ok !$spared->is_removed, 'row not removed';
  is $parent->children->count, 2, 'both rows survive';
}

# --- _delete checkbox array form: only the last value counts ---

{
  # the HTML pattern: hidden input 0 followed by a checked checkbox 1
  my $parent = make_parent('aaaaa', 'bbbbb');
  my $doomed = child_by_value($parent, 'bbbbb');

  $parent->update({ children => [
    { id => child_by_value($parent, 'aaaaa')->id, value => 'aaaaa' },
    { id => $doomed->id, _delete => [0, 1] },
  ]});

  ok $parent->valid, 'update valid';
  ok $doomed->is_marked_for_deletion, '_delete => [0,1]: last value wins, row marked';
  is $parent->children->count, 1, 'row deleted';
}

{
  # unchecked checkbox: values end on 0
  my $parent = make_parent('aaaaa', 'bbbbb');
  my $spared = child_by_value($parent, 'bbbbb');

  $parent->update({ children => [
    { id => child_by_value($parent, 'aaaaa')->id, value => 'aaaaa' },
    { id => $spared->id, _delete => [1, 0] },
  ]});

  ok $parent->valid, 'update valid';
  ok !$spared->is_marked_for_deletion, '_delete => [1,0]: last value wins, row not marked';
  is $parent->children->count, 2, 'both rows survive';
}

# --- _add ---

{
  # an _add row is placed in the cache (for form redisplay) but neither
  # validated nor inserted
  my $parent = make_parent('aaaaa');

  $parent->update({ children => [
    { id => child_by_value($parent, 'aaaaa')->id, value => 'aaaaa' },
    { _add => 1 },
  ]});

  ok $parent->valid, 'parent valid: the empty _add row was not validated';
  my @cached = @{ $parent->children->get_cache||[] };
  is scalar(@cached), 2, '_add row present in the cache';
  my ($added) = grep { !$_->in_storage } @cached;
  ok $added, 'the _add row is not in storage';
  is $added->errors->size, 0, 'no validation errors on the _add row despite empty value';
  is $added->get_attribute_for_json('_add'), 1, '_add pseudo attribute reads back true';
  is Schema->resultset('Child')->search({parent_id=>$parent->id})->count, 1,
    'database still has only the original child';
}

# --- _nop ---

{
  # a row containing _nop is skipped entirely
  my $parent = make_parent('aaaaa');

  $parent->update({ children => [
    { id => child_by_value($parent, 'aaaaa')->id, value => 'aaaaa' },
    { _nop => 1, value => 'zzzzz' },
  ]});

  ok $parent->valid, 'update valid';
  is scalar(@{ $parent->children->get_cache||[] }), 1, '_nop row never entered the cache';
  is $parent->children->count, 1, '_nop row was not created';
}

# --- _restore ---

{
  # step 1: a failed update leaves the row marked for deletion (but intact
  # in the database because nothing mutated)
  my $parent = make_parent('aaaaa', 'bbbbb');
  my $marked = child_by_value($parent, 'bbbbb');

  $parent->update({
    value => '',   # fails presence so the graph never mutates
    children => [
      { id => child_by_value($parent, 'aaaaa')->id, value => 'aaaaa' },
      { id => $marked->id, _delete => 1 },
    ],
  });

  ok $parent->invalid, 'update refused';
  ok $marked->is_marked_for_deletion, 'row still marked after the failed update';
  is Schema->resultset('Child')->search({parent_id=>$parent->id})->count, 2,
    'nothing deleted because the update failed';

  # step 2: _restore unmarks it and the row survives the (now valid) update
  $parent->update({
    value => 'restored value',
    children => [
      { id => child_by_value($parent, 'aaaaa')->id, value => 'aaaaa' },
      { id => $marked->id, _restore => 1 },
    ],
  });

  ok $parent->valid, 'update valid';
  ok !$marked->is_marked_for_deletion, '_restore unmarked the row';
  is Schema->resultset('Child')->search({parent_id=>$parent->id})->count, 2,
    'restored row survives';
  $parent->discard_changes;
  is $parent->value, 'restored value', 'parent update went through';
}

# --- _action => 'delete' / 'nop', scalar and array forms ---

{
  my $parent = make_parent('aaaaa', 'bbbbb');
  my $doomed = child_by_value($parent, 'bbbbb');

  $parent->update({ children => [
    { id => child_by_value($parent, 'aaaaa')->id, value => 'aaaaa' },
    { id => $doomed->id, _action => 'delete' },
  ]});

  ok $parent->valid, 'update valid';
  ok $doomed->is_marked_for_deletion, "_action => 'delete' marked the row";
  is $parent->children->count, 1, 'row deleted';
}

{
  my $parent = make_parent('aaaaa', 'bbbbb');
  my $spared = child_by_value($parent, 'bbbbb');

  $parent->update({ children => [
    { id => child_by_value($parent, 'aaaaa')->id, value => 'aaaaa' },
    { id => $spared->id, _action => 'nop' },
  ]});

  ok $parent->valid, 'update valid';
  ok !$spared->is_marked_for_deletion, "_action => 'nop' leaves the row alone";
  is $parent->children->count, 2, 'both rows survive';
}

{
  # array form: only the last action counts (radio/checkbox submission)
  my $parent = make_parent('aaaaa', 'bbbbb');
  my $doomed = child_by_value($parent, 'bbbbb');

  $parent->update({ children => [
    { id => child_by_value($parent, 'aaaaa')->id, value => 'aaaaa' },
    { id => $doomed->id, _action => ['nop', 'delete'] },
  ]});

  ok $parent->valid, 'update valid';
  ok $doomed->is_marked_for_deletion, "_action => ['nop','delete']: last value wins";
  is $parent->children->count, 1, 'row deleted';
}

{
  my $parent = make_parent('aaaaa', 'bbbbb');
  my $spared = child_by_value($parent, 'bbbbb');

  $parent->update({ children => [
    { id => child_by_value($parent, 'aaaaa')->id, value => 'aaaaa' },
    { id => $spared->id, _action => ['delete', 'nop'] },
  ]});

  ok $parent->valid, 'update valid';
  ok !$spared->is_marked_for_deletion, "_action => ['delete','nop']: last value wins, not marked";
  is $parent->children->count, 2, 'both rows survive';
}

# --- pruning: dropping a nested row prunes its own cached children ---

{
  Schema->resultset("State")->populate([
    [ qw( name abbreviation ) ],
    [ 'Texas', 'TX' ],
  ]);
  Schema->resultset("Role")->populate([
    [ qw( label ) ],
    [ 'admin' ],
    [ 'user' ],
  ]);

  my $person = Schema->resultset('Person')->create({
    username => 'jjnpp',
    first_name => 'john',
    last_name => 'napiorkowski',
    state => { abbreviation => 'TX' },
    person_roles => [ { role_id => 1 }, { role_id => 2 } ],
  });
  ok $person->valid, 'person fixture valid';

  $person = Schema->resultset('Person')->find(
    { 'me.id' => $person->id },
    { prefetch => { person_roles => 'role' } },
  );

  my ($kept_pr, $dropped_pr) =
    sort { $a->role_id <=> $b->role_id } @{ $person->person_roles->get_cache||[] };

  # omit role_id 2 from the new set: its person_role is marked for deletion
  # and the role row cached underneath it is pruned
  $person->update({ person_roles => [ { role_id => 1 } ] });

  ok $person->valid, 'update valid';
  ok !$kept_pr->is_marked_for_deletion, 'kept person_role not marked';
  ok $dropped_pr->is_marked_for_deletion, 'omitted person_role marked for deletion';
  ok $dropped_pr->is_removed, 'omitted person_role is_removed';
  ok $dropped_pr->role->is_pruned, 'cached role under the dropped row is pruned';
  ok $dropped_pr->role->is_removed, 'pruned role reports is_removed';
  ok !$dropped_pr->role->is_marked_for_deletion, 'pruned role is not itself marked for deletion';

  is Schema->resultset('PersonRole')->search({person_id=>$person->id})->count, 1,
    'person_role row deleted';
  ok Schema->resultset('Role')->find($dropped_pr->role_id), 'role row itself survives';
}

done_testing;
