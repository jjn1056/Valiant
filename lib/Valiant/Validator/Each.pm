package Valiant::Validator::Each;

use Moo::Role;
use Valiant::I18N; # So that _t is available in subclasses

with 'Valiant::Validator';
requires 'validate_each';

has allow_undef => (is=>'ro', required=>1, default=>0); # Allows undef and 'not exists'
has allow_blank => (is=>'ro', required=>1, default=>0); # A string is blank if it's empty or contains whitespaces only:
has if => (is=>'ro', predicate=>'has_if');
has unless => (is=>'ro', predicate=>'has_unless');
has on => (is=>'ro', predicate=>'has_on');
has message => (is=>'ro', predicate=>'has_message');
has strict => (is=>'ro', required=>1, default=>0);
has opts => (is=>'ro', required=>1, default=>sub { +{} });
has attributes => (is=>'ro', required=>1);

sub options { 
  my $self = shift;
  return +{ %{$self->opts}, strict=>$self->strict };
}

sub validate {
  my ($self, $object, %options) = @_;
  foreach my $attribute (@{ $self->attributes }) {
    my $value = $object->read_attribute_for_validation($attribute);
    next if $self->allow_undef && not(defined $value);
    next if $self->allow_blank && ($value eq '' || $value =~m/^\s+$/);

    if($self->has_if) {
      my $if = $self->if;
      if((ref($if)||'') eq 'CODE') {
        next unless $if->($object);
      } else {
        if(my $method_cb = $object->can($if)) {
          next unless $method_cb->($object);
        } else {
          die ref($object) ." has no method '$if'";
        }
      }
    }
    if($self->has_unless) {
      my $unless = $self->unless;
      if((ref($unless)||'') eq 'CODE') {
        next if $unless->($object);
      } else {
        if(my $method_cb = $object->can($unless)) {
          next if $method_cb->($object);
        } else {
          die ref($object) ." has no method '$unless'";
        }
      }
    }

    if($self->has_on) {
      my @on = ref($self->on) ? @{$self->on} : ($self->on);
      my $context = $options{context}||'';

      #skip unless $context matches one of the 'on' list.
      my $matches = grep { $_ eq $context } @on;
      next unless $matches;
    }

    $self->validate_each($object, $attribute, $value, %options);
  }
}

sub _requires_one_of {
  my ($self, $args, @list) = @_;
  foreach my $arg (@list) {
    return if defined($args->{$arg});
  }
  my $list = join ', ', @list;
  die "Missing at least one of the following args ($list)";
}

1;
