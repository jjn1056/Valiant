package DBIx::Class::Valiant::Result;

use base qw/DBIx::Class/;

use Role::Tiny::With;
with 'Valiant::Validates';

sub register_column {
  my $self = shift;
  my ($column, $info) = @_;
  $self->next::method(@_);

  use Devel::Dwarn;
  Dwarn \@_;
}

# Gotta jump thru these hoops because of the way the Catalyst
# DBIC model messes with the result namespace but not the schema
# namespace

sub namespace {
  my $self = shift;
  my $source_name = $self->new->result_source->source_name;
  my $class = ref $self;
  $class =~s/::${source_name}$//;
  return $class;
}

sub namespaceX {
  my $self = shift;
  return $self->default_result_namespace;
  warn "...  $self ....";
  my $source_name = $self->result_source->source_name;
  my $class = ref $self;
  $class =~s/::${source_name}$//;
  return $class;
} 


# Trouble here is you can only inject one attribute per model.  Will be an
# issue if you have more than one confirmation validation.

sub inject_attribute {
  my ($class, $attribute_to_inject) = @_;
  my $injection = "
    package $class; 

    __PACKAGE__->mk_group_accessors(simple => '$attribute_to_inject');

    sub new {
      my (\$class, \$args) = \@_;
      my \$val = delete \$args->{$attribute_to_inject};
      my \$new = \$class->next::method(\$args);
      \$new->$attribute_to_inject(\$val);
      return \$new;
    }
  ";

  eval $injection;
  die $@ if $@;
}

1;

