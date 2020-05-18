package Valiant::Name;

use Moo;
use String::CamelCase 'decamelize';
use Text::Autoformat 'autoformat';
use Lingua::EN::Inflexion 'noun';
use Valiant::I18N ();

# These first few are permitted arguments

has class => (is=>'ro', required=>1);
has namespace => (is=>'ro', required=>0, predicate=>'has_namespace');

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
    return lc $class;
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
    $class =~ s/::/_/g;
    return lc noun($class)->singular; 
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
    $class =~ s/^.+:://;
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
    my $formated = autoformat $name, {case=>'title'};
    $formated=~s/\n//g; # some sort of bug in autoformat?
    return $formated;
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
    return Valiant::I18N->make_tag(decamelize($class));
  },
);

sub i18n_class { 'Valiant::I18N' }

has 'i18n' => (
  is => 'ro',
  required => 1,
  default => sub { Module::Runtime::use_module(shift->i18n_class) },
);

has param_key => (
  is => 'ro',
  required => 1,
  lazy => 1,
  default => sub {
    my $self = shift;
    $self->has_namespace ? $self->unnamespaced : $self->singular;
  },
);

sub human {
  my ($self, %options) = @_;
  return $self->_human unless $self->class->can('i18n_scope');

  my @defaults = map {
    $_->model_name->i18n_key;
  } $self->class->ancestors if $self->class->can('ancestors');

  push @defaults, delete $options{default} if exists $options{default};
  push @defaults, $self->_human;

  %options = (
    scope => [$self->class->i18n_scope, 'models'],
    count => 1,
    default => \@defaults,
    %options,
  );

  $self->i18n->translate($defaults[0], %options);
}

package Valiant::Naming;

use Moo::Role;

sub name_class { 'Valiant::Name' }

my %_model_name = ();
sub model_name {
  my ($self) = @_;
  my $class = ref($self) || $self;

  return $_model_name{$class} ||= do {
    my %args = $self->prepare_model_name_args;
    Module::Runtime::use_module($self->name_class)->new(%args);
  };
}

sub prepare_model_name_args {
  my ($self) = @_;
  my $class = ref($self) || $self;
  my %args = (class => $class);
  $args{namespace} = $self->namespace if $self->can('namespace');

  return %args;
}


1;
