package Valiant::Errors;

use Moo;
use Carp;
use Data::Perl::Collection::Array;
use Valiant::NestedError;

has 'object' => (
  is => 'ro',
  required => 1,
  weak_ref => 1,
);

has errors => (
  is => 'ro',
  init_arg => undef,
  lazy => 1,
  required => 1,
  default => sub { Data::Perl::Collection::Array->new() },
  handles => {
    size => 'count',
    count => 'count',
    clear => 'clear',
    blank => 'is_empty',
    empty => 'is_empty',
    uniq => 'uniq',
  }
);

sub i18n_class { 'Valiant::I18N' }

has 'i18n' => (
  is => 'ro',
  required => 1,
  default => sub { Module::Runtime::use_module(shift->i18n_class) },
);

sub error_class { 'Valiant::Error' }

sub any {
  my ($self, $code) = @_;
  $code ||= sub { $_ };
  foreach my $error ($self->errors->all) {
    local $_ = $error;
    return 0 unless $code->($error);
  }
  return 1;
}

sub copy {
  my ($self, $other) = @_;
  my @errors = $other
    ->errors
    ->map(sub {
      my $new = $_->clone;
      $new->object($self->object);
      return $new;
    });

  $self->errors(\@errors);
}

sub import_error {
  my ($self, $error, $options) = @_;
  $self->errors->push(
    Valiant::NestedError->new(
      object => $self->object,
      inner_error => $error,
      %{ $options||+{} },
    )
  );
}

sub merge {
  my ($self, $other) = @_;
  foreach my $error ($other->errors->all) {
    $self->import_error($error);
  }
}

sub where {
  my $self = shift;
  my ($attribute, $type, $options) = $self->_normalize_arguments(@_);
  return $self->errors->grep(sub {
    $_->match($attribute, $type, $options);
  });
}

sub _normalize_arguments {
  my ($self, $attribute, $type, $options) = @_;
  if(ref($type) && ref($type) eq 'CODE') {
    $type = $type->($self->object, $options);
  }
  return (
    $attribute,
    $type,
    $options,
  );
}

# Returns +true+ if the error messages include an error for the given key
# +attribute+, +false+ otherwise.
sub include {
  my ($self, $attribute) = @_;
  return scalar($self->any(sub {
      $_->match($attribute);
  }));
}
*has_key = \&include;

# Delete messages for +key+. Returns the deleted messages.
sub delete {
  my $self = shift;
  my ($attribute, $type, $options) = $self->_normalize_arguments(@_);
  my @deleted = ();
  my $idx = 0;
  foreach my $error($self->errors->all) {
    if($error->match($attribute, $type, $options)) {
      push @deleted, $self->errors->delete($idx);
    } else {
      $idx++
    }
  }
  return @deleted;
}

# Iterates through each error key, value pair in the error messages hash.
# Yields the attribute and the error for that attribute. If the attribute
# has more than one error message, yields once for each error message.
sub each {
  my ($self, $block) = @_;
  foreach my $error($self->errors->all) {
    $block->($error->attribute, $error->message);
  }
}

sub group_by_attribute {
  my $self = shift;
  my %attributes;
  foreach my $error($self->errors->all) {
    next unless $error->has_attribute;
    push @{$attributes{$error->attribute}}, $error;
  }
  return %attributes;
}

# Returns a Hash of attributes with their error messages. If +full_messages+
# is +true+, it will contain full messages (see +full_message+).
sub to_hash {
  my ($self, $full_messages_flag) = @_;
  my %hash = ();
  my %grouped = $self->group_by_attribute;
  foreach my $attr (keys %grouped) {
    $hash{$attr} = [
      map {
        $full_messages_flag ? $_->full_message : $_->message
      } @{ $grouped{$attr}||[] }
    ];
  }
  return %hash;
}

sub as_json {
  my ($self, %options) = @_;
  return $self->to_hash(exists $options{full_messages});
}

sub TO_JSON { shift->as_json(@_) }

# Adds +message+ to the error messages and used validator type to +details+ on +attribute+.
# More than one error can be added to the same +attribute+.
sub add {
  my ($self, $attribute, $type, $options) = @_;
  $type ||= $self->i18n->make_tag('invalid');
  $options ||= +{};
  ($attribute, $type, $options) = $self->_normalize_arguments($attribute, $type, $options);

  my $error = $self->error_class
    ->new(
      object => $self->object,
      attribute => $attribute,
      type => $type,
      i18n => $self->i18n,
      %$options,
    );

  if(my $exception = $options->{strict}) {
    my $message = $error->full_message;
    Carp::croak $message if $exception == 1;
    $exception->throw($message);
  }
 
  use Devel::Dwarn;
  Dwarn $self->errors;

  
  $self->errors->push($error);
  return $error;
}

# Returns +true+ if an error on the attribute with the given message is
# present, or +false+ otherwise. +message+ is treated the same as for +add+.  ~
sub added {
  my ($self, $attribute, $type, $options) = @_;
  $type ||= $self->i18n->make_tag('invalid');
  ($attribute, $type, $options) = $self->_normalize_arguments($attribute, $type, $options);
  if($self->i18n->is_i18n_tag($type)) {
    return $self->any(sub {
      $_->strict_match($attribute, $type, $options);
    });
  } else {
    return scalar(grep {
      $_->type eq $type;
    } $self->messages_for($attribute)) ? 1:0
  }
}

# Similar to ->added except we don't care about options 
sub of_kind {
  my ($self, $attribute, $type) = @_;
  $type ||= $self->i18n->make_tag('invalid');
  ($attribute, $type) = $self->_normalize_arguments($attribute, $type);
  if($self->i18n->is_i18n_tag($type)) {
    return $self->any(sub {
      $_->strict_match($attribute, $type);
    });
  } else {
    return scalar(grep {
      $_->type eq $type;
    } $self->messages_for($attribute)) ? 1:0
  }
}

# Returns all the full error messages in an array.
sub full_messages {
  my $self = shift;
  return $self->errors->map(sub { $_->full_message });
}

# Returns all the full error messages for a given attribute in an array.
sub full_messages_for {
  my ($self, $attribute) = @_;
  return map {
    $_->full_message
  } $self->where($attribute);
}

sub messages_for {
  my ($self, $attribute) = @_;
  return map {
    $_->message
  } $self->where($attribute)
}

# Returns a full message for a given attribute
sub full_message {
  my ($self, $attribute, $message) = @_;
  $self->error_class->full_message(
    $attribute,
    $message,
    $self->object,
    $self->i18n);
}

sub generate_message {
  my ($self, $attribute, $type, $options) = @_;
  $type ||= $self->i18n->make_tag('invalid');
  return $self->error_class->generate_message(
    $attribute,
    $type,
    $self->object,
    $options,
    $self->i18n);
}

sub _dump {
  require Data::Dumper;
  return Data::Dumper::Dumper( +{shift->to_hash(full_messages=>1)} );
}

1;

=head1 TITLE

Valiant::Errors - A collection of errors associated with an object

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head1 METHODS

=head1 SEE ALSO
 
L<Valiant>, L<Valiant::Error>.

=head1 AUTHOR
 
See L<Valiant>  
    
=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut

1;
