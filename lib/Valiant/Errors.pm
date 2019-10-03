package Valiant::Errors;

use Moo;
use List::Util;

has _fields => (
  init_arg => 'fields',
  is => 'rw',
  required => 1,
);

has _mapping => (
  init_arg => undef,
  is => 'rw',
  required => 1,
  builder => '_build__mapping'
);

  # Initialize the field mappings to a hash of the initialized fields
  # with a value of an arrayref.

  sub _build__mapping {
    my %initial = map {
      $_ => [];
    } shift->fields;
    return \%initial;
  }

sub fields { return @{ shift->_fields } }

sub field {
  my ($self, $field) = @_;
  return my @errors = @{ 
    $self->_mapping->{$field}
    || die "No field '$field' in Errors"
  };
}

sub add {
  my ($self, $field, $message) = @_;
  push @{ $self->_mapping->{$field} }, $message;
}

sub unshift {
  my ($self, $field, $message) = @_;
  unshift @{ $self->_mapping->{$field} }, $message;
}

# Delete all errors for a given field
sub delete {
  my ($self, $field) = @_;
  $self->_mapping->{$field} = [];
  return $self;
}

# Clear all errors
sub clear {
  my ($self) = @_;
  $self->delete($_)
    for $self->fields;
  return $self;
}

# The given error is already attached to this field
sub added {
  my ($self, $field, $to_check) = @_;
  foreach my $error ($self->field($field)) {
    return 1 if $to_check eq $error;
  }
  return 0;
}

# Return the number of errors for a field, or 0/false if none
*include = \&count_for;
*size_for = \&count_for;
sub count_for {
  my ($self, $field) = @_;
  return scalar(@{$self->_mapping->{$field}});
}

# fields with errors
sub keys {
  my ($self) = @_;
  return my @keys = grep {
    $self->count_for($_) > 0;
  } $self->fields;
}

# Return the number of errors, or 0/false if none
*size = \&count;
sub count {
  my ($self) = @_;
  return my $count = List::Util::sum map {
    $self->count_for($_);
  } $self->fields;
}

# Is the error list empty or not?
*blank = \&empty;
sub empty {
  my ($self) = @_;
  return my $is_empty = $self->count ? 0:1;
}

#Untranslated messages added to a field
sub messages {
  my ($self, $field) = @_;
  return my @messages = @{$self->_mapping->{$field} || []};
}

# translated message for  given attribute and message TODO
sub full_message {
  my ($self, $field, $message) = @_;
  my ($message_to_translate) = grep { $message eq $_ } $self->messages($field);
  # magic translation stuff
  return $message_to_translate;
}

# For each field with an error message, execute a callback
sub each {
  my ($self, $callback) = @_;
  foreach my $field ($self->keys) {
    $callback->($field, $_)
      for $self->messages($field);
  }
  return $self;
}

# Is the error list empty or not?
*has_key = \&include;
sub include {
  my ($self) = @_;
  return my $is_empty = $self->count ? 0:1;
}

# Copy error state from another error object. This overwrites
# The original.
sub copy {
  my ($self, $other) = @_;
  $self->_fields([$other->_fields]);
  $self->_mapping([$other->_mapping]);
  return $self;
}

# merge info from a target error into this one
sub merge {
  my ($self, $other) = @_;
  $self->_fields([ @{$self->_fields}, @{$other->_fields} ]);
  $self->_mapping({ %{$self->_mapping}, %{$other->_mapping} });
  return $self;
}




1;
