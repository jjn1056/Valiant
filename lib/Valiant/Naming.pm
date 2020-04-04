package Valiant::Name;

use Moo;
use String::CamelCase 'decamelize';
use Text::Autoformat 'autoformat';
use Lingua::EN::Inflexion 'noun';

# These first few are permitted arguments

has class => (is=>'ro', required=>1);
has namespace => (is=>'ro', required=>1, predicate=>'has_namespace');

# All these are generated at runtime

#around BUILDARGS => sub {
#  my ($orig, $class, @args) = @_;
#  my $args = $class->$orig(@args);
#  if(my $ns = $args->{namespace}) {
#    my $class = $args->{class};
#    $class =~s/^${ns}:://;
#    $arg->{unnamespaced} = $class;
#  }
#  return $args;
#};

has 'unnamespaced' => (
  is => 'ro',
  init_arg => undef,
  required => 0,
  lazy => 1,
  predicate => 'has_unnamespaced',
  default => sub { 
    my $self = shift;
    return unless $self->has_namespace;
    my $class = $self->class;
    my $ns = $self->namespace;
    $class =~s/^${ns}:://;
    return $class;
  },
);

has 'singular' => (
  is => 'ro',
  init_arg => undef,
  lazy => 1,
  required => 1,
  default => sub {
    my $self = shift;
    my $class = $self->class;
    $class = decamelize($class);
    $class =  ~s/::/_/g;
    return noun($class)->singular; 
  },
);

has 'plural' => (
  is => 'ro',
  init_arg => undef,
  lazy => 1,
  required => 1,
  default => sub {
    my $self = shift;
    return noun($self->singular)->plural;
  },
);

has 'element' => (
  is => 'ro',
  init_arg => undef,
  lazy => 1,
  required => 1,
  default => sub {
    my $self = shift;
    my $class = $self->class;
    $class =  ~s/^.+:://;
    $class = decamelize($class);
  },
);

has _human => (
  is => 'ro',
  init_arg => undef,
  lazy => 1,
  required => 1,
  default =>  sub {
    my $self = shift;
    my $name = $self->element;
    $name =~s/_/ /g;
    return autoformat $name, {case=>'title'};
  },
);

has i18n_key => (
  is => 'ro',
  init_arg => undef,
  lazy => 1,
  required => 1,
  default =>  sub {
    my $self = shift;
    my $class = $self->class;
    $class =~s/::/\//g;
    return decamelize($class);
  },
);

sub i18n_class { 'Valiant::I18N' }

has 'i18n' => (
  is => 'ro',
  required => 1,
  default => sub { Module::Runtime::use_module(shift->i18n_class) },
);

sub human {
  my ($self, %options) = @_;
  return $self->_human unless $self->can('i18n_scope');

  my @defaults = map {
    $_->i18n_key;
  } $self->ancestors if $self->can('ancestors');

  push @defaults, delete $options{default} if exists $options{default};
  push @defaults, $self->_human;

  my $tag = shift @defaults;

  %options = (
    scope => [$self->i18n_scope, 'models'],
    count => 1,
    default => \@defaults,
    %options,
  );

  $self->i18n->translate($tag, %options);
}

package Valiant::Naming;

use Moo::Role;

sub name_class { 'Valiant::Name' }

has model_name => (
  is => 'ro',
  init_arg => undef,
  lazy => 1,
  required => 1,
  default =>  sub {
    my $self = shift;
    my $class = ref($self);
    my %args = (class => ref($class));
    if($self->can('use_relative_model_naming') && $self->use_relative_model_naming) {
      $args{namespace} = ($class=~m/^(.+)::/)[0];
    }
    return Module::Runtime::use_module($self->name_class)->new(%args);
  },
);

1;
