package Valiant::Errors;

use Moo;
use List::Util;
use overload
#  '@{}'    => sub { shift->child_nodes },
  '%{}'    => sub { shift->to_hash },
  #  bool     => sub {1},
  #  '""'     => sub { shift->to_string },
  fallback => 0;

has 'object' => (
  is => 'ro',
  required => 1,
  weak_ref => 1,
);

has ['details', 'messages'] => (
  is => 'rwp',
  required => 1,
  default => sub { +{} }
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
  delete $self->_set_details->{$key};
  delete $self->_set_messages->{$key};
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
      $key => [
        map {
          $self->full_message($key, $_) 
        } @{ $self->messages->{$key} }
      ];
    } CORE::keys %{ $self->messages};
  } else {
    %{ $self->messages };
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
  # If the message is ['key', %args] that means we want to localize it
  if((ref($message)||'') eq 'ARRAY') {
    # TODO need to remove some things from %options
    return $self->generate_message($attribute, $message, $options);
  } else {
    return $message;
  }
}

sub _normalize_detail {
  my ($self, $message, $options) = @_;
  # TODO need to remove some things from %options
  return +{ error => $message, %{$options||+{}} };
}

# $attribute, ?$message, ?\%options where $message is Str|ArrayRef|CodeRef
sub add {
  my ($self, $attribute) = (shift, shift);
  my %options = ref($_[-1]) eq 'HASH' ? %{ pop @_ } : ();
  my $message = shift || ['Is Invalid'];

  $message = delete $options{message} if $options{message};
  $message = $message->($self, $attribute, \%options) if (ref($message)||'') eq 'CODE';

  my $detail  = $self->_normalize_detail($message, \%options);
  $message = $self->_normalize_message($attribute, $message, \%options);

  if(my $exception = $options{strict}) {
    die $self->full_message($attribute, $message) if $exception == 1;
    $exception->throw($self->full_message($attribute, $message));
  }

  my %messages = %{ $self->messages };
  push @{$messages{$attribute}}, $message;
  $self->_set_messages(\%messages);

  my %details = %{ $self->details };
  push @{ $details{$attribute} }, $detail;
  $self->_set_details(\%details);
}

sub added {
  my ($self, $attribute) = (shift, shift);
  my %options = ref($_[-1]) eq 'HASH' ? %{ pop @_ } : ();
  my $message = shift || 'Is Invalid';

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

sub full_messages_for {
  my ($self, $attribute) = @_;
  return map {
    $self->full_message($attribute, $_);
  } @{ $self->messages->{$attribute} };
}

sub full_message {
  my ($self, $attribute, $message) = @_;
  # TODO a lot
  return $message;
}

sub generate_message {
  my ($self, $attribute, $message, $options) = @_;
  my $human_attribute_name = $self->object->human_attribute_name($attribute, %$options);
  
  my $value = $attribute ne 'base' ? 
    $self->object->read_attribute_for_validation($attribute) :
    undef;
  
  my %options = (
    model => $self->object->model_name->human,
    attribute => $human_attribute_name,
    value => $value,
    object => $self->object,
    %$options,
  );

  my $key = join ' ',
    grep { defined($_) }
    ($human_attribute_name,$message);

  return $self->object->localize($key, %options);
}

1;
