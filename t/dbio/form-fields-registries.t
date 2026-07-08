use Test::Most;
use Test::Needs 'DBIO', 'DBIO::SQLite';

# The FormFields registries end-to-end on a deployed schema: select
# options (option_label / option_value tag resolution), checkboxes,
# radio buttons, registered form fields, and the read_attribute_for_html
# fallback chain.
#
# NOTE the registries are class data shared through the component, so the
# auto-read fallback chain (which only applies while NO form field is
# registered anywhere) is asserted before any add_form_field_for call.

{
  package FF2::Schema::Result::Status;

  use base 'DBIO::Core';

  __PACKAGE__->load_components('Valiant::Result::HTML::FormFields', 'Valiant::Result');
  __PACKAGE__->table("status");
  __PACKAGE__->resultset_class('FF2::Schema::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1, tag => 'option_value' },
    label => { data_type => 'varchar', is_nullable => 0, size => 24, tag => 'option_label' },
  );
  __PACKAGE__->set_primary_key("id");

  package FF2::Schema::Result::Tag;

  use base 'DBIO::Core';

  __PACKAGE__->load_components('Valiant::Result::HTML::FormFields', 'Valiant::Result');
  __PACKAGE__->table("tag");
  __PACKAGE__->resultset_class('FF2::Schema::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1, tags => ['checkbox_value'] },
    label => { data_type => 'varchar', is_nullable => 0, size => 24, tags => ['checkbox_label'] },
  );
  __PACKAGE__->set_primary_key("id");

  package FF2::Schema::Result::Article;

  use base 'DBIO::Core';

  __PACKAGE__->load_components('Valiant::Result::HTML::FormFields', 'Valiant::Result');
  __PACKAGE__->table("article");
  __PACKAGE__->resultset_class('FF2::Schema::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    title => { data_type => 'varchar', is_nullable => 0, size => 96 },
    status_id => { data_type => 'integer', is_nullable => 1, is_foreign_key => 1 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->belongs_to(status => 'FF2::Schema::Result::Status', { 'foreign.id' => 'self.status_id' });
  __PACKAGE__->validates(title => (presence => 1));

  __PACKAGE__->add_select_options_rs_for('status_id', sub {
    my ($self, %options) = @_;
    return $self->result_source->schema->resultset('Status')->search_rs({}, { order_by => 'label' });
  });

  __PACKAGE__->add_checkbox_rs_for('tag_ids', sub {
    my ($self, %options) = @_;
    return $self->result_source->schema->resultset('Tag')->search_rs({}, { order_by => 'label' });
  });

  __PACKAGE__->add_radio_buttons_for('priority', sub {
    my ($self, %options) = @_;
    return qw(low medium high);
  });

  sub word_count {
    my $self = shift;
    my @words = split /\s+/, ($self->title||'');
    return scalar @words;
  }

  package FF2::Schema::Result::Author;

  use base 'DBIO::Core';

  __PACKAGE__->load_components('Valiant::Result::HTML::FormFields', 'Valiant::Result');
  __PACKAGE__->table("author");
  __PACKAGE__->resultset_class('FF2::Schema::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    name => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");

  package FF2::Schema::ResultSet;

  use base 'DBIO::ResultSet';

  __PACKAGE__->load_components('Valiant::ResultSet');

  package FF2::Schema;

  use base 'DBIO::Schema';

  __PACKAGE__->register_class(Status => 'FF2::Schema::Result::Status');
  __PACKAGE__->register_class(Tag => 'FF2::Schema::Result::Tag');
  __PACKAGE__->register_class(Article => 'FF2::Schema::Result::Article');
  __PACKAGE__->register_class(Author => 'FF2::Schema::Result::Author');
}

ok my $schema = FF2::Schema->connect('dbi:SQLite:dbname=:memory:', '', '', { RaiseError => 1 });
$schema->deploy;

ok my $draft     = $schema->resultset('Status')->create({ label => 'draft' });
ok my $published = $schema->resultset('Status')->create({ label => 'published' });
ok my $perl_tag  = $schema->resultset('Tag')->create({ label => 'perl' });
ok my $dbio_tag  = $schema->resultset('Tag')->create({ label => 'dbio' });

ok my $article = $schema->resultset('Article')->create({
  title => 'a five word article title',
  status_id => $draft->id,
});
ok $article->valid, 'article fixture valid';

# --- read_attribute_for_html auto chain (no form fields registered yet) ---

{
  is $article->read_attribute_for_html('title'), 'a five word article title',
    'column value read first';
  is $article->read_attribute_for_html('word_count'), 5,
    'plain method used when the attribute is not a column';
  ok my $status = $article->read_attribute_for_html('status'),
    'single relationship readable';
  ok $status->isa('FF2::Schema::Result::Status'), 'it is the related row';
  is $status->id, $draft->id, 'and the right one';
  is $article->read_attribute_for_html('_delete'), 0,
    '_delete pseudo attribute reflects is_marked_for_deletion';
  is $article->read_attribute_for_html('_add'), 1,
    '_add pseudo attribute is always true';
  ok my $bad = $article->read_attribute_for_html('no_such_thing'),
    'unknown attribute still returns something';
  ok $bad->isa('Valiant::BadAttribute'),
    'unknown attribute falls through to Valiant::BadAttribute';
}

# --- select options via option_value / option_label tags ---

{
  my ($rs, $label_method, $value_method) = $article->select_options_rs_for('status_id');
  ok $rs->isa('FF2::Schema::ResultSet'), 'registry coderef produced the resultset';
  is $label_method, 'label', 'label method resolved from the option_label tag';
  is $value_method, 'id', 'value method resolved from the option_value tag';

  is_deeply $article->select_options_for('status_id'),
    [ [ 'draft', $draft->id ], [ 'published', $published->id ] ],
    'select_options_for returns ordered label/value pairs';
}

# --- checkboxes via checkbox_value / checkbox_label tags ---

{
  my ($rs, $label_method, $value_method) = $article->checkbox_rs_for('tag_ids');
  is $label_method, 'label', 'label method resolved from the checkbox_label tag';
  is $value_method, 'id', 'value method resolved from the checkbox_value tag';

  is_deeply $article->checkboxes_for('tag_ids'),
    [ [ 'dbio', $dbio_tag->id ], [ 'perl', $perl_tag->id ] ],
    'checkboxes_for returns ordered label/value pairs';
}

# --- radio buttons from a plain list coderef ---

{
  is_deeply [ $article->radio_buttons_for('priority') ],
    [ qw(low medium high) ],
    'radio_buttons_for returns the coderef list';
}

# --- registered form fields (registered at runtime: see NOTE above) ---

{
  my $author_class = 'FF2::Schema::Result::Author';
  ok !$author_class->has_form_fields, 'no form fields registered yet';

  $author_class->add_form_field_for('display_name', sub {
    my ($self, $column) = @_;
    return uc($self->name);
  });

  ok $author_class->has_form_fields, 'form field registered';
  ok $author_class->has_form_field('display_name'), 'by name';
  ok !$author_class->has_form_field('name'), 'only the registered one';

  ok my $author = $schema->resultset('Author')->create({ name => 'john' });
  is $author->read_form_field_for('display_name'), 'JOHN',
    'read_form_field_for runs the registered coderef';
  is $author->read_attribute_for_html('display_name'), 'JOHN',
    'read_attribute_for_html prefers the registered field';
  ok !$author->read_attribute_for_html('name'),
    'once any field is registered, unregistered attributes are not auto-read';

  throws_ok {
    $author->read_form_field_for('nope');
  } qr/Can't find a form field for column 'nope'/,
    'read_form_field_for refuses unregistered fields';
}

done_testing;
