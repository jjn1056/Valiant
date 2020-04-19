package Valiant::Translation;

use Moo::Role;
use Text::Autoformat 'autoformat';

with 'Valiant::Naming';

sub i18n_class { 'Valiant::I18N' }

has 'i18n' => (
  is => 'ro',
  required => 1,
  lazy => 1,
  default => sub { Module::Runtime::use_module(shift->i18n_class) },
);

sub i18n_scope { 'valiant' }

sub human_attribute_name {
  my ($self, $attribute, $options) = @_;
  return undef unless defined($attribute);

  # TODO I think we need to clean $option here so I don't need to manually
  # set count=>1 as I do below.

  my @defaults = ();
  my $i18n_scope = $self->i18n_scope;
  my @parts = split '.', $attribute;
  my $attribute_name = pop @parts;
  my $namespace = join '/', @parts if @parts;
  my $attributes_scope = "${i18n_scope}.attributes";

  if($namespace) {
      @defaults = map {
        my $class = $_;
        "${attributes_scope}.${\$class->i18n_key}/${namespace}.${attribute}"     
      } grep { $_->can('i18n_key') } $self->ancestors;
  } else {
      @defaults = map {
        my $class = $_;
        "${attributes_scope}.${\$class->i18n_key}.${attribute}"    
      } grep { $_->can('i18n_key') } $self->ancestors;
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
    $human_attr = autoformat($human_attr, +{case=>'title'});
    $human_attr =~s/[\n]//g; # Is this a bug in Text::Autoformat???
    $human_attr;
  };

  my $key = shift @defaults;
  $options->{default} = \@defaults;
  $options->{count} = 1 unless exists $options->{count};

  return  my $localized = $self->i18n->translate($key, %{$options||+{}});
}

my %injected_role = ();
my $inject_role_if_needed = sub {
  my $class = shift;
  return if $injected_role{$class};
  if(Role::Tiny->is_role($class)) {

    eval qq[
      package ${class}; 
      sub does_roles { shift->maybe::next::method(\@_) }
    ];

    my $around = \&{"${class}::around"};
    $around->(does_roles => sub {
      my ($orig, $self) = @_;
      return ($self->$orig, $class);
    });

    $injected_role{$class} = 1;
  }
};

sub ancestors {
  my $class = shift;
  $class = ref($class) if ref($class);
  $class->$inject_role_if_needed;

  no strict "refs";
  my @ancestors = ();

  push @ancestors, grep {
    Role::Tiny::does_role($_, __PACKAGE__);
  } @{"${class}::ISA"};

  push @ancestors, $class->does_roles
    if $class->can('does_roles');

  return @ancestors;
}

1;
