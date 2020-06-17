package Example;

use Catalyst;
use Valiant::I18N;

__PACKAGE__->setup_plugins([qw/
  Authentication
  Session
  Session::State::Cookie
  Session::Store::Cookie
  RedirectTo
  URI
/]);

__PACKAGE__->config(
  disable_component_resolution_regex_fallback => 1,
  'Plugin::Session' => { storage_secret_key => 'abc123' },
  'Plugin::Authentication' => {
    default_realm => 'members',
    realms => {
      members => {
        credential => {
          class => 'Password',
          password_field => 'password',
          # password_type => 'self_check'
          password_type => 'clear',
        },
        store => {
          class => 'DBIx::Class',
          user_model => 'Schema::Person',
        },
      },
    },
  },
  'Model::Schema' => {
    traits => ['SchemaProxy'],
    schema_class => 'Example::Schema',
    connect_info => {
      dsn => 'dbi:Pg:dbname=jnapiorkowski',
      user => 'postgres',
      password => ''
    }
  },
);

# TODO deal with the nested transactions and improve the naming so that things
# sort better in standard directory listings (and less ugly).

use App::Sqitch;
use App::Sqitch::Config;
use App::Sqitch::Command::add;
use SQL::Translator;
use SQL::Translator::Diff;
use Digest::MD5;

sub create_migration {
  my ($class, $change, $notes) = @_;
  $change = 'test' unless defined $change;
  $notes = 'none' unless defined $notes;

  my $schema = $class->model('Schema');
  my $dir = $class->path_to;

  my $current_ddl = SQL::Translator->new(
   no_comments => 1, # comment has timestamp so that breaks the md5 checksum
   producer => 'PostgreSQL',
   parser => 'SQL::Translator::Parser::DBIx::Class',
   parser_args => { dbic_schema => $schema },
  )->translate;

  my $current_checksum = Digest::MD5::md5_hex($current_ddl);

  my ($last_created_schema) =  map { $_ } sort { $b cmp $a } $dir->subdir('sql','schemas')->children;
  if($last_created_schema) {
    my ($last_checksum) = ("$last_created_schema"=~m/\.(.+?)\.sql$/);
    if($current_checksum eq $last_checksum) {
      warn "No Change!";
      return;
    }
  }

  # Save the DDL since there's a change or its the first one.
  my @d = localtime;
  my $file = $dir->subdir('sql','schemas')
    ->file(sprintf "%02d-%02d-%02d@%02d:%02d:%02d.%s.sql", $d[5]+1900,$d[4]+1,@d[3,2,1,0], $current_checksum);
  $file->spew($current_ddl);

  # Generate a Diff
  my $last_ddl = $last_created_schema->slurp;
  my $schema_last = SQL::Translator->new(
    parser => 'PostgreSQL',
    data => $last_ddl,
  )->translate;

  my $schema_current = SQL::Translator->new(
    parser => 'PostgreSQL',
    data => $current_ddl,
  )->translate;

  my $deploy_diff = SQL::Translator::Diff->new({
    output_db => 'PostgreSQL',
    ignore_constraint_names => 1,
    target_schema => $schema_current,
    source_schema => $schema_last,
  })->compute_differences->produce_diff_sql;

  my $revert_diff = SQL::Translator::Diff->new({
    output_db => 'PostgreSQL',
    ignore_constraint_names => 1,
    target_schema => $schema_last,
    source_schema => $schema_current,
  })->compute_differences->produce_diff_sql;

  my $change_name = time.'-'.$change;
  my $path = $dir->file('sqitch.conf');
  warn "sqith $path";
  local $ENV{SQITCH_CONFIG} = $path; #ugly, I wonder if there's a better way

  my $cmd = App::Sqitch::Command::add->new(
    sqitch => App::Sqitch->new(
      config => App::Sqitch::Config->new()
    ),
    change_name => $change_name,
    note => [$notes],
    template_directory => $dir,
  );

  $cmd->execute;

  my $deploy_script = $dir->subdir('sql','deploy')->file("${change_name}.sql")->slurp;
  $deploy_script=~s/^\-\- XXX Add DDLs here\.$/$deploy_diff/smg;
  $dir->subdir('sql','deploy')->file("${change_name}.sql")->spew($deploy_script);

  my $revert_script = $dir->subdir('sql','revert')->file("${change_name}.sql")->slurp;
  $revert_script=~s/^\-\- XXX Add DDLs here\.$/$revert_diff/smg;
  $dir->subdir('sql','revert')->file("${change_name}.sql")->spew($revert_script);

  print "Migration created\n";
}

__PACKAGE__->setup();
__PACKAGE__->meta->make_immutable();

