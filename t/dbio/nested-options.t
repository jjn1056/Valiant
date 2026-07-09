use Test::Most;
use Test::Needs 'DBIO', 'DBIO::SQLite';

# Each accept_nested_for option exercised in isolation, positive and negative
# cases: reject_if, limit (scalar and coderef, via create AND update),
# update_only, find_with_uniques (1 and 'allow_create'), allow_destroy
# (constant and coderef, plus the no-allow_destroy no-op).
#
# Result class variants share the same tables; each has_many variant gets its
# own belongs_to partner so reverse relationship resolution works.

{
  package NO1::Result;

  use base 'DBIO::Base';

  __PACKAGE__->load_components(qw/Valiant::Result Core/);

  package NO1::ResultSet;

  use base 'DBIO::ResultSet';

  __PACKAGE__->load_components('Valiant::ResultSet');

  ## reject_if on a has_many

  package NO1::Album::Reject;

  use base 'NO1::Result';

  __PACKAGE__->table("album");
  __PACKAGE__->resultset_class('NO1::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    artist_id => { data_type => 'integer', is_nullable => 0, is_foreign_key => 1 },
    title => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->belongs_to(artist => 'NO1::Artist::Reject', { 'foreign.id' => 'self.artist_id' });
  __PACKAGE__->validates(title => (presence => 1, length => [3, 48]));

  package NO1::Artist::Reject;

  use base 'NO1::Result';

  __PACKAGE__->table("artist");
  __PACKAGE__->resultset_class('NO1::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    name => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->has_many(albums => 'NO1::Album::Reject', { 'foreign.artist_id' => 'self.id' });
  __PACKAGE__->validates(name => (presence => 1, length => [2, 48]));

  our @reject_if_args;
  __PACKAGE__->accept_nested_for(albums => {
    reject_if => sub {
      my ($self, $params) = @_;
      @reject_if_args = ($self, $params);
      return (grep { ($_->{title}||'') eq 'REJECTED' } @$params) ? 1:0;
    },
  });

  ## limit as a scalar

  package NO1::Album::Limit;

  use base 'NO1::Result';

  __PACKAGE__->table("album");
  __PACKAGE__->resultset_class('NO1::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    artist_id => { data_type => 'integer', is_nullable => 0, is_foreign_key => 1 },
    title => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->belongs_to(artist => 'NO1::Artist::Limit', { 'foreign.id' => 'self.artist_id' });
  __PACKAGE__->validates(title => (presence => 1, length => [3, 48]));

  package NO1::Artist::Limit;

  use base 'NO1::Result';

  __PACKAGE__->table("artist");
  __PACKAGE__->resultset_class('NO1::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    name => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->has_many(albums => 'NO1::Album::Limit', { 'foreign.artist_id' => 'self.id' });
  __PACKAGE__->validates(name => (presence => 1, length => [2, 48]));
  __PACKAGE__->accept_nested_for(albums => { limit => 2 });

  ## limit as a coderef

  package NO1::Album::LimitCode;

  use base 'NO1::Result';

  __PACKAGE__->table("album");
  __PACKAGE__->resultset_class('NO1::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    artist_id => { data_type => 'integer', is_nullable => 0, is_foreign_key => 1 },
    title => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->belongs_to(artist => 'NO1::Artist::LimitCode', { 'foreign.id' => 'self.artist_id' });
  __PACKAGE__->validates(title => (presence => 1, length => [3, 48]));

  package NO1::Artist::LimitCode;

  use base 'NO1::Result';

  __PACKAGE__->table("artist");
  __PACKAGE__->resultset_class('NO1::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    name => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->has_many(albums => 'NO1::Album::LimitCode', { 'foreign.artist_id' => 'self.id' });
  __PACKAGE__->validates(name => (presence => 1, length => [2, 48]));
  __PACKAGE__->accept_nested_for(albums => { limit => sub { my $self = shift; 3 } });

  ## update_only on a might_have (and its absence)

  package NO1::Bio::UpdateOnly;

  use base 'NO1::Result';

  __PACKAGE__->table("bio");
  __PACKAGE__->resultset_class('NO1::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    artist_id => { data_type => 'integer', is_nullable => 0, is_foreign_key => 1 },
    note => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->belongs_to(artist => 'NO1::Artist::UpdateOnly', { 'foreign.id' => 'self.artist_id' });
  __PACKAGE__->validates(note => (presence => 1, length => [2, 48]));

  package NO1::Artist::UpdateOnly;

  use base 'NO1::Result';

  __PACKAGE__->table("artist");
  __PACKAGE__->resultset_class('NO1::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    name => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->might_have(bio => 'NO1::Bio::UpdateOnly', { 'foreign.artist_id' => 'self.id' });
  __PACKAGE__->validates(name => (presence => 1, length => [2, 48]));
  __PACKAGE__->accept_nested_for(bio => { update_only => 1 });

  package NO1::Bio::NoUpdateOnly;

  use base 'NO1::Result';

  __PACKAGE__->table("bio");
  __PACKAGE__->resultset_class('NO1::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    artist_id => { data_type => 'integer', is_nullable => 0, is_foreign_key => 1 },
    note => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->belongs_to(artist => 'NO1::Artist::NoUpdateOnly', { 'foreign.id' => 'self.artist_id' });
  __PACKAGE__->validates(note => (presence => 1, length => [2, 48]));

  package NO1::Artist::NoUpdateOnly;

  use base 'NO1::Result';

  __PACKAGE__->table("artist");
  __PACKAGE__->resultset_class('NO1::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    name => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->might_have(bio => 'NO1::Bio::NoUpdateOnly', { 'foreign.artist_id' => 'self.id' });
  __PACKAGE__->validates(name => (presence => 1, length => [2, 48]));
  __PACKAGE__->accept_nested_for('bio');

  ## find_with_uniques on a belongs_to (strict and allow_create)

  package NO1::Producer;

  use base 'NO1::Result';

  __PACKAGE__->table("producer");
  __PACKAGE__->resultset_class('NO1::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    name => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->add_unique_constraint(['name']);
  __PACKAGE__->validates(name => (presence => 1, length => [2, 48]));

  package NO1::Artist::FindUniq;

  use base 'NO1::Result';

  __PACKAGE__->table("artist2");
  __PACKAGE__->resultset_class('NO1::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    name => { data_type => 'varchar', is_nullable => 0, size => 48 },
    producer_id => { data_type => 'integer', is_nullable => 1, is_foreign_key => 1 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->belongs_to(producer => 'NO1::Producer', { 'foreign.id' => 'self.producer_id' });
  __PACKAGE__->validates(name => (presence => 1, length => [2, 48]));
  __PACKAGE__->accept_nested_for(producer => { find_with_uniques => 1 });

  package NO1::Artist::FindUniqCreate;

  use base 'NO1::Result';

  __PACKAGE__->table("artist2");
  __PACKAGE__->resultset_class('NO1::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    name => { data_type => 'varchar', is_nullable => 0, size => 48 },
    producer_id => { data_type => 'integer', is_nullable => 1, is_foreign_key => 1 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->belongs_to(producer => 'NO1::Producer', { 'foreign.id' => 'self.producer_id' });
  __PACKAGE__->validates(name => (presence => 1, length => [2, 48]));
  __PACKAGE__->accept_nested_for(producer => { find_with_uniques => 'allow_create' });

  ## allow_destroy: constant, coderef and absent

  package NO1::Album::Destroy;

  use base 'NO1::Result';

  __PACKAGE__->table("album");
  __PACKAGE__->resultset_class('NO1::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    artist_id => { data_type => 'integer', is_nullable => 0, is_foreign_key => 1 },
    title => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->belongs_to(artist => 'NO1::Artist::Destroy', { 'foreign.id' => 'self.artist_id' });
  __PACKAGE__->validates(title => (presence => 1, length => [3, 48]));

  package NO1::Artist::Destroy;

  use base 'NO1::Result';

  __PACKAGE__->table("artist");
  __PACKAGE__->resultset_class('NO1::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    name => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->has_many(albums => 'NO1::Album::Destroy', { 'foreign.artist_id' => 'self.id' });
  __PACKAGE__->validates(name => (presence => 1, length => [2, 48]));
  # This section exercises the omission-diff, so it also needs delete_omitted
  # (Rails-parity: allow_destroy alone no longer implies replace-set deletes).
  __PACKAGE__->accept_nested_for(albums => { allow_destroy => 1, delete_omitted => 1 });

  package NO1::Album::DestroyCode;

  use base 'NO1::Result';

  __PACKAGE__->table("album");
  __PACKAGE__->resultset_class('NO1::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    artist_id => { data_type => 'integer', is_nullable => 0, is_foreign_key => 1 },
    title => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->belongs_to(artist => 'NO1::Artist::DestroyCode', { 'foreign.id' => 'self.artist_id' });
  __PACKAGE__->validates(title => (presence => 1, length => [3, 48]));

  package NO1::Artist::DestroyCode;

  use base 'NO1::Result';

  __PACKAGE__->table("artist");
  __PACKAGE__->resultset_class('NO1::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    name => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->has_many(albums => 'NO1::Album::DestroyCode', { 'foreign.artist_id' => 'self.id' });
  __PACKAGE__->validates(name => (presence => 1, length => [2, 48]));
  # This section exercises the omission-diff, so delete_omitted needs the same
  # predicate as allow_destroy (Rails-parity: allow_destroy alone no longer
  # implies replace-set deletes).
  my $destroyer_only = sub { my $self = shift; $self->name eq 'destroyer' ? 1:0 };
  __PACKAGE__->accept_nested_for(albums => {
    allow_destroy => $destroyer_only,
    delete_omitted => $destroyer_only,
  });

  package NO1::Album::Keep;

  use base 'NO1::Result';

  __PACKAGE__->table("album");
  __PACKAGE__->resultset_class('NO1::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    artist_id => { data_type => 'integer', is_nullable => 0, is_foreign_key => 1 },
    title => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->belongs_to(artist => 'NO1::Artist::Keep', { 'foreign.id' => 'self.artist_id' });
  __PACKAGE__->validates(title => (presence => 1, length => [3, 48]));

  package NO1::Artist::Keep;

  use base 'NO1::Result';

  __PACKAGE__->table("artist");
  __PACKAGE__->resultset_class('NO1::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    name => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->has_many(albums => 'NO1::Album::Keep', { 'foreign.artist_id' => 'self.id' });
  __PACKAGE__->validates(name => (presence => 1, length => [2, 48]));
  __PACKAGE__->accept_nested_for('albums');

  package NO1::Schema;

  use base 'DBIO::Schema';

  __PACKAGE__->register_class(ArtistReject => 'NO1::Artist::Reject');
  __PACKAGE__->register_class(AlbumReject => 'NO1::Album::Reject');
  __PACKAGE__->register_class(ArtistLimit => 'NO1::Artist::Limit');
  __PACKAGE__->register_class(AlbumLimit => 'NO1::Album::Limit');
  __PACKAGE__->register_class(ArtistLimitCode => 'NO1::Artist::LimitCode');
  __PACKAGE__->register_class(AlbumLimitCode => 'NO1::Album::LimitCode');
  __PACKAGE__->register_class(ArtistUpdateOnly => 'NO1::Artist::UpdateOnly');
  __PACKAGE__->register_class(BioUpdateOnly => 'NO1::Bio::UpdateOnly');
  __PACKAGE__->register_class(ArtistNoUpdateOnly => 'NO1::Artist::NoUpdateOnly');
  __PACKAGE__->register_class(BioNoUpdateOnly => 'NO1::Bio::NoUpdateOnly');
  __PACKAGE__->register_class(Producer => 'NO1::Producer');
  __PACKAGE__->register_class(ArtistFindUniq => 'NO1::Artist::FindUniq');
  __PACKAGE__->register_class(ArtistFindUniqCreate => 'NO1::Artist::FindUniqCreate');
  __PACKAGE__->register_class(ArtistDestroy => 'NO1::Artist::Destroy');
  __PACKAGE__->register_class(AlbumDestroy => 'NO1::Album::Destroy');
  __PACKAGE__->register_class(ArtistDestroyCode => 'NO1::Artist::DestroyCode');
  __PACKAGE__->register_class(AlbumDestroyCode => 'NO1::Album::DestroyCode');
  __PACKAGE__->register_class(ArtistKeep => 'NO1::Artist::Keep');
  __PACKAGE__->register_class(AlbumKeep => 'NO1::Album::Keep');
}

ok my $schema = NO1::Schema->connect('dbi:SQLite:dbname=:memory:', '', '', { RaiseError => 1 });
$schema->deploy;

# --- reject_if ---

{
  # negative control: coderef returns false so the nested set is processed
  ok my $artist = $schema->resultset('ArtistReject')->create({
    name => 'Nirvana',
    albums => [ { title => 'Bleach' }, { title => 'Nevermind' } ],
  }), 'create with albums the coderef accepts';
  ok $artist->valid, 'graph valid';
  is $artist->albums->count, 2, 'both albums inserted';

  ok my ($cb_self, $cb_params) = @NO1::Artist::Reject::reject_if_args, 'reject_if coderef was invoked';
  ok $cb_self->isa('NO1::Artist::Reject'), 'coderef gets the parent result as first argument';
  is ref($cb_params), 'ARRAY', 'coderef gets the raw nested params as second argument';

  # positive: coderef returns true so the whole nested set is skipped
  ok my $skipped = $schema->resultset('ArtistReject')->create({
    name => 'Fugazi',
    albums => [ { title => 'REJECTED' }, { title => 'Repeater' } ],
  }), 'create with albums the coderef rejects';
  ok $skipped->valid, 'parent still valid';
  ok $skipped->in_storage, 'parent inserted';
  is $skipped->albums->count, 0, 'no albums inserted: reject_if skipped the whole set';
}

# --- limit (scalar) ---

{
  # under the limit
  ok my $artist = $schema->resultset('ArtistLimit')->create({
    name => 'Low Rollers',
    albums => [ { title => 'One One One' }, { title => 'Two Two Two' } ],
  }), 'create at the limit';
  ok $artist->valid, 'graph valid';
  is $artist->albums->count, 2, 'two albums inserted';

  # over the limit on create
  eval {
    $schema->resultset('ArtistLimit')->create({
      name => 'Overachievers',
      albums => [ { title => 'AAA' }, { title => 'BBB' }, { title => 'CCC' } ],
    });
  };
  ok my $err = $@, 'over-limit create throws';
  ok $err->isa('DBIO::Valiant::Util::Exception::TooManyRows'), 'TooManyRows exception';
  like "$err", qr/Relationship albums on artist can't create more that 2 rows; attempted 3/,
    'exception message carries limit and attempted count';
  is $schema->resultset('ArtistLimit')->search({name=>'Overachievers'})->count, 0,
    'parent not inserted';

  # over the limit on update (previously only the create path was covered)
  eval {
    $artist->update({
      albums => [ { title => 'AAA' }, { title => 'BBB' }, { title => 'CCC' } ],
    });
  };
  ok my $update_err = $@, 'over-limit update throws';
  ok $update_err->isa('DBIO::Valiant::Util::Exception::TooManyRows'), 'TooManyRows exception via update';
  like "$update_err", qr/Relationship albums on artist can't create more that 2 rows; attempted 3/,
    'update exception message carries limit and attempted count';
  is $artist->albums->count, 2, 'album rows unchanged after refused update';
}

# --- limit (coderef) ---

{
  ok my $artist = $schema->resultset('ArtistLimitCode')->create({
    name => 'Code Limits',
    albums => [ { title => 'AAA' }, { title => 'BBB' }, { title => 'CCC' } ],
  }), 'create at the coderef limit';
  ok $artist->valid, 'graph valid';
  is $artist->albums->count, 3, 'three albums inserted (limit coderef returns 3)';

  eval {
    $schema->resultset('ArtistLimitCode')->create({
      name => 'Code Breakers',
      albums => [ { title => 'AAA' }, { title => 'BBB' }, { title => 'CCC' }, { title => 'DDD' } ],
    });
  };
  ok my $err = $@, 'over-coderef-limit create throws';
  ok $err->isa('DBIO::Valiant::Util::Exception::TooManyRows'), 'TooManyRows exception';
  like "$err", qr/can't create more that 3 rows; attempted 4/, 'coderef limit was evaluated';
}

# --- update_only ---

{
  ok my $artist = $schema->resultset('ArtistUpdateOnly')->create({
    name => 'Updater',
    bio => { note => 'original note' },
  }), 'created artist with bio';
  ok $artist->valid, 'graph valid';
  ok my $bio_id = $artist->bio->id, 'bio has an id';
  is $schema->resultset('BioUpdateOnly')->count, 1, 'one bio row';

  # update_only: no PK in the nested params still updates the existing row
  $artist->update({ bio => { note => 'revised note' } });
  ok $artist->valid, 'update valid';
  is $schema->resultset('BioUpdateOnly')->count, 1, 'still one bio row';
  is $schema->resultset('BioUpdateOnly')->find($bio_id)->note, 'revised note',
    'existing bio row updated in place without a PK';

  # update_only with no existing related row creates one
  ok my $fresh = $schema->resultset('ArtistUpdateOnly')->create({ name => 'Fresh Start' });
  ok $fresh->valid, 'artist without bio valid';
  $fresh->discard_changes;
  $fresh->update({ bio => { note => 'first note' } });
  ok $fresh->valid, 'update valid';
  is $fresh->bio->note, 'first note', 'bio created when none existed';
}

{
  # without update_only a PK-less nested update creates a NEW related row
  ok my $artist = $schema->resultset('ArtistNoUpdateOnly')->create({
    name => 'Replacer',
    bio => { note => 'original note' },
  }), 'created artist with bio';
  ok $artist->valid, 'graph valid';
  ok my $bio_id = $artist->bio->id, 'bio has an id';
  my $bio_count = $schema->resultset('BioNoUpdateOnly')->search({artist_id=>$artist->id})->count;
  is $bio_count, 1, 'one bio row for this artist';

  $artist->discard_changes;
  $artist->update({ bio => { note => 'replacement note' } });
  ok $artist->valid, 'update valid';
  isnt $artist->bio->id, $bio_id, 'a new bio row replaced the old one in the relationship';
  is $schema->resultset('BioNoUpdateOnly')->find($bio_id)->note, 'original note',
    'original row not updated';
}

# --- find_with_uniques ---

{
  ok my $rick = $schema->resultset('Producer')->create({ name => 'Rick Rubin' });
  ok $rick->valid, 'producer fixture valid';
  is $schema->resultset('Producer')->count, 1, 'one producer';

  # found via the unique key: linked, no new row
  ok my $artist = $schema->resultset('ArtistFindUniq')->create({
    name => 'Slayer',
    producer => { name => 'Rick Rubin' },
  }), 'create with existing producer';
  ok $artist->valid, 'graph valid';
  is $artist->producer->id, $rick->id, 'linked to the found producer';
  is $schema->resultset('Producer')->count, 1, 'no new producer row';

  # not found: related_not_found error, nothing created
  ok my $lost = $schema->resultset('ArtistFindUniq')->create({
    name => 'Unknown Act',
    producer => { name => 'Nobody Home' },
  }), 'create with unknown producer';
  ok $lost->invalid, 'graph invalid';
  ok !$lost->in_storage, 'artist not inserted';
  is_deeply [$lost->errors->full_messages_for('producer')],
    ["Producer Related Model 'Producer' Not Found"],
    'related_not_found error rendered with full message';
  is $schema->resultset('Producer')->count, 1, 'no producer row created';

  # allow_create: not found means create
  ok my $creator = $schema->resultset('ArtistFindUniqCreate')->create({
    name => 'DIY Act',
    producer => { name => 'Newcomer' },
  }), 'create with allow_create and unknown producer';
  ok $creator->valid, 'graph valid';
  ok $creator->in_storage, 'artist inserted';
  is $schema->resultset('Producer')->count, 2, 'new producer row created';
  is $creator->producer->name, 'Newcomer', 'linked to the new producer';
}

# --- allow_destroy (constant) ---

{
  ok my $artist = $schema->resultset('ArtistDestroy')->create({
    name => 'Shrinker',
    albums => [ { title => 'Keep Me' }, { title => 'Drop Me' } ],
  }), 'created artist with two albums';
  ok $artist->valid, 'graph valid';
  my ($keep, $drop) = $artist->albums->search({}, { order_by => 'id' })->all;

  # omitting a row from the nested set marks and deletes it
  $artist = $schema->resultset('ArtistDestroy')->find({ 'me.id' => $artist->id }, { prefetch => 'albums' });
  $artist->update({ albums => [ { id => $keep->id, title => 'Keep Me' } ] });
  ok $artist->valid, 'update valid';
  is $schema->resultset('AlbumDestroy')->search({artist_id=>$artist->id})->count, 1,
    'omitted album row deleted from the database';
  ok $schema->resultset('AlbumDestroy')->find($keep->id), 'kept album still present';
  ok !$schema->resultset('AlbumDestroy')->find($drop->id), 'dropped album gone';
}

# --- allow_destroy (coderef) ---

{
  ok my $destroyer = $schema->resultset('ArtistDestroyCode')->create({
    name => 'destroyer',
    albums => [ { title => 'Keep Me' }, { title => 'Drop Me' } ],
  }), 'created artist the coderef allows to destroy';
  ok $destroyer->valid, 'graph valid';
  my ($d_keep, $d_drop) = $destroyer->albums->search({}, { order_by => 'id' })->all;

  $destroyer = $schema->resultset('ArtistDestroyCode')->find({ 'me.id' => $destroyer->id }, { prefetch => 'albums' });
  $destroyer->update({ albums => [ { id => $d_keep->id, title => 'Keep Me' } ] });
  ok $destroyer->valid, 'update valid';
  is $schema->resultset('AlbumDestroyCode')->search({artist_id=>$destroyer->id})->count, 1,
    'coderef returned true: omitted album deleted';

  ok my $keeper = $schema->resultset('ArtistDestroyCode')->create({
    name => 'keeper',
    albums => [ { title => 'Keep Me' }, { title => 'Stay Put' } ],
  }), 'created artist the coderef refuses to destroy';
  ok $keeper->valid, 'graph valid';
  my ($k_keep, $k_stay) = $keeper->albums->search({}, { order_by => 'id' })->all;

  $keeper = $schema->resultset('ArtistDestroyCode')->find({ 'me.id' => $keeper->id }, { prefetch => 'albums' });
  $keeper->update({ albums => [ { id => $k_keep->id, title => 'Keep Me' } ] });
  ok $keeper->valid, 'update valid';
  is $schema->resultset('AlbumDestroyCode')->search({artist_id=>$keeper->id})->count, 2,
    'coderef returned false: omitted album survives';
}

# --- no allow_destroy: omission and _delete are both no-ops ---

{
  ok my $artist = $schema->resultset('ArtistKeep')->create({
    name => 'Hoarder',
    albums => [ { title => 'First One' }, { title => 'Second One' } ],
  }), 'created artist with two albums';
  ok $artist->valid, 'graph valid';
  my ($first, $second) = $artist->albums->search({}, { order_by => 'id' })->all;

  # omitted rows are not deleted
  $artist = $schema->resultset('ArtistKeep')->find({ 'me.id' => $artist->id }, { prefetch => 'albums' });
  $artist->update({ albums => [ { id => $first->id, title => 'First One' } ] });
  ok $artist->valid, 'update valid';
  is $schema->resultset('AlbumKeep')->search({artist_id=>$artist->id})->count, 2,
    'omitted album not deleted without allow_destroy';

  # an explicit _delete marker is also a no-op
  $artist = $schema->resultset('ArtistKeep')->find({ 'me.id' => $artist->id }, { prefetch => 'albums' });
  $artist->update({ albums => [
    { id => $first->id, title => 'First One' },
    { id => $second->id, _delete => 1 },
  ] });
  ok $artist->valid, 'update valid';
  my ($marked) = grep { $_->id == $second->id } @{ $artist->albums->get_cache||[] };
  ok $marked, 'row with _delete still in the cache';
  ok !$marked->is_marked_for_deletion, '_delete without allow_destroy did not mark the row';
  is $schema->resultset('AlbumKeep')->search({artist_id=>$artist->id})->count, 2,
    '_delete without allow_destroy left the database untouched';
}

done_testing;
