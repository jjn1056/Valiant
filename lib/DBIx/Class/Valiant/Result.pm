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

# We override here because we really want the uninflated values for the columns.
# Otherwise if we try to inflate first we can get an error since the value has not
# been validated and may not inflate.

sub read_attribute_for_validation {
  my ($self, $attribute) = @_;
  return unless defined $attribute;
  return $self->get_column($attribute) if $self->result_source->has_column($attribute);

  #TODO If the relationship is a single we might want to return the result
  return $self->related_resultset($attribute) if $self->has_relationship($attribute);
  return $self->$attribute if $self->can($attribute); 
}

# Provide basic uniqueness checking for columns.  This is basically a dumb DB lookup.  
# Its probably fine for light work but you'll need something more performant when your
# table gets big.

sub is_unique {
  my ($self, $attribute_name, $value) = @_;
  # Don't do this check unless the user is actually trying to change the
  # value (otherwise it will fail all the time
  return 1 unless $self->is_column_changed($attribute_name);
  my $found = $self->result_source->resultset->find({$attribute_name=>$value});
  return $found ? 0:1;
}

# 
sub mark_for_deletion {
  my ($self) = @_;
  $self->{__valiant_kiss_of_death} = 1;
}

sub unmark_for_deletion {
  my ($self) = @_;
  $self->{__valiant_kiss_of_death} = 0;
}

sub is_marked_for_deletion {
  my ($self) = @_;
  return $self->{__valiant_kiss_of_death} ? 1:0;
}

sub delete_if_in_storage {
  my ($self) = @_;
  $self->delete if $self->in_storage;  #TODO some sort of relationship handling...
}

1;

