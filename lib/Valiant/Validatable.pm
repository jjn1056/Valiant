package Valiant::Validatable;

use Moo::Role;
use Module::Runtime;

sub error_class { 'Valiant::Errors' }

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

sub naming_class { 'Valiant::Validatable::Naming' }

has 'model_name' => (
  is => 'ro',
  required => 1,
  lazy => 1,
  init_arg => undef,
  builder => '_build_naming',
);

  sub _build_naming {
    my $self = shift;
    my $naming_class = $self->naming_class;
    return Module::Runtime::use_module($naming_class)->new(object=>$self);
  }

sub read_attribute_for_validation {
  my ($self, $attribute) = @_;
  return my $value = $self->$attribute
    if $self->can($attribute);
}

sub human_attribute_name {
  my ($self, $attribute, $options) = @_;
  return undef if $attribute eq '_base';

  $options->{count} = 1;

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
          "${attributes_scope}.${\$class->model_name->i18n_key}/${namespace}.${attribute}"     
        } $self->object->ancestors;
    } else {
        @defaults = map {
          my $class = $_;
          "${attributes_scope}.${\$class->model_name->i18n_key}.${attribute}"    
        } $self->object->ancestors;
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

  return my $localized = $self->i18n->translate($key, %{$options||+{}});
}

sub validate {
  my ($self, %args) = @_;
  # TODO deal with if, unless, on, etc
  foreach my $validation ($self->validations) {
    my %options = %{$validation->[1]};
    $validation->[0]($self, %options);
  }
}

## TODO valid, invalid, i18n_key, docs for i18n_scope

1;
