package Valiant::Validatable;

# TODO Need to make this not polute the namespace so much :(

use Moo::Role;
use Module::Runtime;
use String::CamelCase 'decamelize';

sub error_class { 'Valiant::Errors' }

has 'validated' => (is=>'rw', required=>1, init_args=>undef, default=>0);

has '_errors' => (
  is => 'ro',
  required => 1,
  lazy => 1,
  init_arg => undef,
  builder => '_build_errors',
  handles => {
    add_error => 'add',
  },
);

sub i18n_class { 'Valiant::I18N' }

has 'i18n' => (
  is => 'ro',
  required => 1,
  default => sub { Module::Runtime::use_module(shift->i18n_class) },
);

  sub _build_errors {
    my ($self) = @_;
    my $error_class = $self->error_class;
    return Module::Runtime::use_module($error_class)->new(object=>$self, i18n=>$self->i18n);
  }

sub errors {
  my $self = shift;
  if(my $attribute = shift) {
    return @{ $self->_errors->messages->{$attribute}||[] };
  } else {
    return $self->_errors;
  }
}

sub i18n_key {
  my ($self_or_class) = @_;
  my $class = ref($self_or_class) ? ref($self_or_class) : $self_or_class;
  $class =~s/::/\//g;
  return decamelize $class; # TODO cache this on init
}

has model_name => (
  is => 'ro',
  required => 1,
  lazy => 1,
  init_arg => undef,
  default => sub {
    my $self = shift;
    my ($last) = reverse split '::', ref $self;
    return lc $last;
  },
);

has _human => (
  is => 'ro',
  required => 1,
  lazy => 1,
  init_arg => undef,
  default =>  sub {
    my $self = shift;
    my $name = $self->model_name;
    $name =~s/_/ /g;
    return my $_human = ucfirst $name;
  },
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

# sub BUILD { shift->validate }  ## TODO Not sure if we want this or not

sub read_attribute_for_validation {
  my ($self, $attribute) = @_;
  return my $value = $self->$attribute
    if $self->can($attribute);
}

sub human_attribute_name {
  my ($self, $attribute, $options) = @_;
  return undef if $attribute eq '_base';

  # TODO I think we need to clean $option here so I don't need to manually
  # set count=>1 as I do below.

  my @defaults = ();
  if($self->can('i18n_scope')) { # Rails defines this in activemodel translations
    my $i18n_scope = $self->i18n_scope;
    my @parts = split '.', $attribute;
    my $attribute_name = pop @parts;
    my $namespace = join '/', @parts if @parts;
    my $attributes_scope = "${i18n_scope}.attributes";

    if($namespace) {
        @defaults = map {
          my $class = $_;
          "${attributes_scope}.${\$class->i18n_key}/${namespace}.${attribute}"     
        } $self->ancestors;
    } else {
        @defaults = map {
          my $class = $_;
          "${attributes_scope}.${\$class->i18n_key}.${attribute}"    
        } $self->ancestors;
    }
  }

  @defaults = map { $self->i18n->make_tag($_) } (@defaults, "attributes.${attribute}");

  # Not sure if this should move up above the preceeding map...
  if(exists $options->{default}) {
    my $default = delete $options->{default};
    my @default = ref($default) ? @$default : ($default);
    push @defaults, @default;
  }

  # The final default is just our best attempt to make a name out of the actual
  # attribute name.  This is passed as a plain string so we don't actually try
  # to localize it.
  push @defaults, do {
    my $human_attr = $attribute;
    $human_attr =~s/_/ /g;
    $human_attr = ucfirst $human_attr;
    $human_attr;
  };

  my $key = shift @defaults;
  $options->{default} = \@defaults;

  return my $localized = $self->i18n->translate($key, %{$options||+{}}, count=>1);
}

# Returns the current validation state if validations have been run
# and no args are passed.  If args are passed then clear state and
# re run validations with new args

sub valid {
  my $self = shift;
  $self->validate(@_) if @_ || !$self->validated;
  return $self->errors->size ? 0:1;
}

sub invalid { shift->valid(@_) ? 0:1 }

sub clear_validated {
  my $self = shift;
  $self->errors->clear;
  $self->validated(0);
}

sub validate {
  my ($self, %args) = @_;
  $self->clear_validated if $self->validated;
  foreach my $validation ($self->validations) {
    my %validation_args = (%{$validation->[1]}, %args);
    $validation->[0]($self, \%validation_args);
  }
  $self->validated(1);
  return $self;
}



## TODO docs for i18n_scope
## TODO probably use BUILD to call validation right awwy (unless { validate=>0 } or something).
## TODO if we run BUILD then we probably need to pull context from args as well (possible message and strict???)
## TODO around has for compact validation declares (in the has statement
## has user => (is=>'ro', validates=>[ length=>[2,25], presence=>1 ] );
1;
