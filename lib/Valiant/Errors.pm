package Valiant::Errors;

use Moo;
use Scalar::Util 'blessed';
use Module::Runtime;
use Data::Dumper ();
use Carp;

## TODO need overloading on boolean cast to check errors size. 
# $errors->{user_name}->[0] for example needs to work

has 'object' => (
  is => 'ro',
  required => 1,
  weak_ref => 1,
);

has ['details', 'messages', 'nested'] => (
  is => 'rwp',
  required => 1,
  default => sub { +{} }
);

sub i18n_class { 'Valiant::I18N' }

has 'i18n' => (
  is => 'ro',
  required => 1,
  default => sub { Module::Runtime::use_module(shift->i18n_class) },
);

sub copy {
  my ($self, $other) = @_;
  $self->_set_details($other->details);
  $self->_set_messages($other->messages);
}

sub merge {
  my ($self, $other) = @_;
  $self->_set_details(+{ %{$self->details}, %{$other->details} });
  $self->set_->messages(+{ %{$self->messages}, %{$other->messages} });
}

sub slice {
  my ($self, @keys) = @_;
  my %new_details; @new_details{@keys} = @{$self->details}{@keys};
  my %new_messages; @new_messages{@keys} = @{$self->messages}{@keys};
  $self->_set_details(\%new_details);
  $self->_set_messages(\%new_messages);
}

sub clear {
  my ($self) = @_;
  $self->_set_details(+{});
  $self->_set_messages(+{});
}

sub include {
  my ($self, $key) = @_;
  return $self->messages->{$key} ? 1 : undef;
}

*key = \&include;
*has_key = \&include;

sub delete {
  my ($self, $key) = @_;
  delete $self->{details}->{$key}; # maybe too much a hack...
  delete $self->{messages}->{$key};
}

sub messages_for {
  my ($self, $key) = @_;
  return $self->messages->{$key};
}

sub each {
  my ($self, $cb) = @_;
  foreach my $key (keys %{$self->messages}) {
    my $proto = $self->messages->{$key};
    if(ref $proto) {
      $cb->($key, $_) for @$proto;
    } else {
      $cb->($key, $proto);
    }
  }
}

sub values {
  my ($self) = @_;
  return values %{$self->messages};
}

sub values_flat {
  my ($self) = @_;
  return map { ref $_ eq 'ARRAY' ? @$_ : $_ } $self->values;
}

sub size {
  my ($self) = @_;
  return scalar($self->values_flat);
}

sub keys {
  my ($self) = @_;
  return keys %{$self->messages};
}

sub empty {
  my ($self) = @_;
  return $self->size ? 1:0;
}
*blank = \&empty;

sub to_hash {
  my ($self, %options) = @_;
  if($options{full_messages}) {
    map {
      my $key = $_;
      my @values = map {
          $self->full_message($key, $_) 
        } @{ $self->messages->{$key} };
      my $values = ref($values[0]) ? $values[0] : \@values; # handle nested errors
      $key => $values;
    } CORE::keys %{ $self->messages ||+{} };
  } else {
    %{ $self->messages ||+{} };
  }
}

sub TO_JSON {
  my ($self, %options) = @_;
  my %messages = $self->to_hash(%options);
  return \%messages;
}
*to_json = \&TO_JSON;

sub _normalize_message {
  my ($self, $attribute, $message, $options) = @_;
  # If the message is a scalar ref, that means we want to localize it
  if($self->i18n->is_i18n_tag($message)) {
    my %options = %{$options||+{}};
    delete @options{qw(if unless allow_undef allow_blank strict message)};
    return $self->generate_message($attribute, $message, \%options);
  } else {
    return $message;
  }
}
    
sub _normalize_detail {
  my ($self, $message, $options) = @_;
  my %options = %{$options||+{}};
  delete @options{qw(if unless allow_undef allow_blank strict message)};
  return +{ error => $message, %options };
}

# $attribute, ?$message, ?\%options where $message is Str|ArrayRef|CodeRef
sub add {
  my ($self, $attribute) = (shift, shift);
  my %options = ref($_[-1]) eq 'HASH' ? %{ pop @_ } : ();
  my $message = shift || $self->i18n->make_tag('invalid');

  # TODO starting to look like a pile of hacks
  # also not sure this goes all the way down the rabbit hole
  if(blessed($message) and $message->isa('Valiant::Errors')) {
    my %messages = %{ $self->messages ||+{} };
    if(ref($messages{$attribute}[0])||'' eq 'HASH') {
      my %new = %{$message->messages};
      foreach my $key(CORE::keys %new) {
        push @{$messages{$attribute}[0]{$key}}, @{ $new{$key} }
      }
    } else {
      unshift @{$messages{$attribute}}, $message->messages;
    }
    $self->_set_messages(\%messages);

    my %details = %{ $self->details ||+{} };
    if(ref($details{$attribute}[0])||'' eq 'HASH') {
      my %new = %{$message->details};
      foreach my $key(CORE::keys %new) {
        push @{$details{$attribute}[0]{$key}}, @{ $new{$key} }
      }
    } else {
      unshift @{ $details{$attribute} }, $message->details;
    }

    $self->_set_details(\%details);

    return;
  }

  $message = delete $options{message} if $options{message};
  $message = $message->($self, $attribute, \%options) if (ref($message)||'') eq 'CODE';

  my $detail  = $self->_normalize_detail($message, \%options);
  $message = $self->_normalize_message($attribute, $message, \%options);

  if(my $exception = $options{strict}) {
    Carp::croak $self->full_message($attribute, $message) if $exception == 1;
    $exception->throw($self->full_message($attribute, $message));
  }

  my %messages = %{ $self->messages ||+{} };
  push @{$messages{$attribute}}, $message;
  $self->_set_messages(\%messages);

  my %details = %{ $self->details ||+{} };
  push @{ $details{$attribute} }, $detail;
  $self->_set_details(\%details);
}

# TODO I think this should allow an instance of ::Error instead of just a message
# and possible an index....?
#
sub added {
  my ($self, $attribute) = (shift, shift);
  my %options = ref($_[-1]) eq 'HASH' ? %{ pop @_ } : ();
  my $message = shift || $self->i18n->make_tag('invalid');

  $message = $message->($self) if (ref($message)||'') eq 'CODE';
  my @messages = @{ $self->messages_for($attribute) ||[] };

  return scalar(grep { $_ eq $message } @messages) ? 1:0;
}

sub full_messages {
  my ($self) = @_;
  return my @messages = map {
    my $attribute = $_;
    map {
      $self->full_message($attribute, $_);
    } @{ $self->messages->{$attribute} };
  } CORE::keys %{ $self->messages };
}
*to_a = \&full_messages;

# TODO need to figure out nested paths here...
sub full_messages_for {
  my ($self, $attribute) = @_;
  return map {
    $self->full_message($attribute, $_);
  } @{ $self->messages->{$attribute} };
}

sub full_message { # should be 'format_message' :)
  my ($self, $attribute, $message) = @_;
  return $message if $attribute eq '_base';

  if(ref $message) {
    if(ref $message eq 'HASH') {

      my %result = ();
      foreach my $key (CORE::keys %$message) {
        foreach my $m (@{ $message->{$key} }) {
          my $full_message = $self->full_message($key, $m); # TODO this probably doesn't localise the right model name
          push @{$result{$key}}, $full_message;
        }
      }
      return \%result;
    }
  }
  
  my @defaults = ();
  if($self->object->can('i18n_scope')) {
    my $i18n_scope = $self->object->i18n_scope;
    my @parts = split '.', $attribute;
    my $attribute_name = pop @parts;
    my $namespace = join '/', @parts if @parts;
    my $attributes_scope = "${i18n_scope}.errors.models";
    if($namespace) {
      @defaults = map {
        my $class = $_;
        "${attributes_scope}.${\$class->i18n_key}/${namespace}.attributes.${attribute_name}.format",
        "${attributes_scope}.${\$class->i18n_key}/${namespace}.format";      
      } $self->object->ancestors;
    } else {
      @defaults = map {
        my $class = $_;
        "${attributes_scope}.${\$class->i18n_key}.attributes.${attribute_name}.format",
        "${attributes_scope}.${\$class->i18n_key}.format";    
      } $self->object->ancestors;
    }
  }

  @defaults = map { $self->i18n->make_tag($_) } @defaults;

  push @defaults, $self->i18n->make_tag("errors.format");
  push @defaults, "{{attribute}} {{message}}";

  my $attr_name = $self->object->human_attribute_name($attribute);
  
  return my $translated = $self->i18n->translate(
    shift @defaults,
    default => \@defaults,
    attribute => $attr_name,
    message => $message
  );
}

sub generate_message {
  my ($self, $attribute, $type, $options) = @_;
  $type ||= $self->i18n->make_tag('invalid');
  $options ||= +{};
  $type = delete $options->{message} if $self->i18n->is_i18n_tag($options->{message}||'');

  my $value = $attribute ne '_base' ? 
    $self->object->read_attribute_for_validation($attribute) :
    undef;

  my %options = (
    model => $self->object->human,
    attribute => $self->object->human_attribute_name($attribute, $options),
    value => $value,
    object => $self->object,
    %{$options||+{}},
  );

  my @defaults = ();
  if($self->object->can('i18n_scope')) {
    my $i18n_scope = $self->object->i18n_scope;
    @defaults = map {
      my $class = $_;
      "${i18n_scope}.errors.models.${\$class->i18n_key}.attributes.${attribute}.${$type}",
      "${i18n_scope}.errors.models.${\$class->i18n_key}.${$type}";      
    } $self->object->ancestors;
    push @defaults, "${i18n_scope}.errors.messages.${$type}";
  }

  push @defaults, "errors.attributes.${attribute}.${$type}";
  push @defaults, "errors.messages.${$type}";

  @defaults = map { $self->i18n->make_tag($_) } @defaults;

  my $key = shift(@defaults);
  if($options->{message}) {
    my $message = delete $options->{message};
    @defaults = ref($message) ? @$message : ($message);
  }
  $options{default} = \@defaults;

  return my $translated = $self->i18n->translate($key, %options);
}

sub _dump {
  return Data::Dumper::Dumper( +{shift->to_hash(full_messages=>1)} );
}

1;
