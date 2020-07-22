package Valiant::Errors;

use Moo;
use Data::Perl::Collection::Array;
use Valiant::NestedError;
use Valiant::Util 'throw_exception';

use overload (
  bool  => sub { shift->size ? 1:0 },
);

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
    return 1 if $code->($error);
  }
  return 0;
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
  use Devel::Dwarn;
  #Dwarn $other;
  foreach my $error ($other->errors->all) {
    $self->import_error($error);
  }
}

sub where {
  my $self = shift;
  my ($attribute, $type, $options) = $self->_normalize_arguments(@_);
  return $self->errors->grep(sub {
    $_->match($attribute, $type, $options);
  })->all;
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
    $block->(($error->attribute||'*'), $error->message);
  }
}

sub model_errors {
  my $self = shift;
  my @errors;
  foreach my $error($self->errors->all) {
    push @errors, $error if !$error->has_attribute || !defined($error->attribute);
  }
  return @errors;
}

sub model_errors_array {
  my ($self, $full_messages_flag) = @_;
  return map {
    $full_messages_flag ? $_->full_message : $_->message
  } $self->model_errors;
}

sub group_by_attribute {
  my $self = shift;
  my %attributes;
  foreach my $error($self->errors->all) {
    next unless $error->has_attribute;
    push @{$attributes{$error->attribute||'*'}}, $error;
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
  unless(defined($type)) {
    $type = $self->i18n->make_tag('invalid');
  }
  $options ||= +{};
  ($attribute, $type, $options) = $self->_normalize_arguments($attribute, $type, $options);

  # hack for nested..
  if(Scalar::Util::blessed($type) and $type->isa('Valiant::Errors')) {
    my @existing = $self->where($attribute);
    ## Todo this needs to be first if it doesn't exist
    foreach my $existing(@existing) {
      next unless Scalar::Util::blessed($existing->type) and $existing->type->isa('Valiant::Errors');
      $existing->type->merge($type);
      return;
    }
  }
  # end hack

  my $error = $self->error_class
    ->new(
      object => $self->object,
      attribute => $attribute,
      type => $type,
      i18n => $self->i18n,
      options => $options,
    );

  if(my $exception = $options->{strict}) {
    my $message = $error->full_message;
    throw_exception('Strict' => (msg=>$message)) if $exception == 1;
    $exception->throw($message); # If not 1 then assume its a package name.
  }
 
  $self->errors->push($error);
  return $error;
}

# Returns +true+ if an error on the attribute with the given message is
# present, or +false+ otherwise. +message+ is treated the same as for +add+.  ~
sub added {
  my ($self, $attribute, $type, $options) = @_;

  ## TODO ok so if the $attribute refers to an object which can->errors maybe we
  ## need to call $self->$attribute->errors->add(undef, $type, $options) instead
  ## so that any global errors to a nested object end in in the right place?
  ## Afterwards we need to associate the nested object errors to $self so that
  ## we know errors exist (for stuff like to_hash and all_errors, etc.

  $type ||= $self->i18n->make_tag('invalid');
  ($attribute, $type, $options) = $self->_normalize_arguments($attribute, $type, $options);
  if($self->i18n->is_i18n_tag($type)) {
    return $self->any(sub {
      $_->strict_match($attribute, $type, $options);
    });
  } else {
    return scalar(grep {
      $_ eq $type;
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
      $_ eq $type;
    } $self->messages_for($attribute)) ? 1:0
  }
}

# Returns all the full error messages in an array.
sub full_messages {
  my $self = shift;
  $self->full_messages_collection->all;
}

sub full_messages_collection {
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

# Returns a full message for a given attribute.  Class method
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
