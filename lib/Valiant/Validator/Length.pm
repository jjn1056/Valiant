package Valiant::Validator::Length;

use Moo;
use Valiant::I18N;

with 'Valiant::Validator::Each';

has maximum => (is=>'ro', predicate=>'has_maximum');
has minimum => (is=>'ro', predicate=>'has_minimum');
has in => (is=>'ro', predicate=>'has_in');
has is => (is=>'ro', predicate=>'has_is');

has too_long => (is=>'ro', required=>1, default=>sub {_t 'too_long'});
has too_short => (is=>'ro', required=>1, default=>sub {_t 'too_short'});
has wrong_length => (is=>'ro', required=>1, default=>sub {_t 'wrong_length'});

sub BUILD {
  my ($self, $args) = @_;
  $self->_requires_one_of($args, 'maximum', 'minimum', 'in', 'is');
}

sub validate_each {
  my ($self, $record, $attribute, $value) = @_;
  my $length = length($value);
  my %opts = (%{$self->options}, count=>$length);
  if($self->has_maximum) {
    $record->errors->add($attribute, $self->too_long, \%opts) if $length > $self->maximum;
  }
  if($self->has_minimum) {
    $record->errors->add($attribute, $self->too_short, \%opts) if $length < $self->minimum;
  }
  if($self->has_in) {
    my ($min, $max) = @{$self->in};
    $record->errors->add($attribute, $self->too_long, \%opts) if $length > $max;
    $record->errors->add($attribute, $self->too_short, \%opts) if $length < $min;
  }
  if($self->has_is) {
    $record->errors->add($attribute, $self->wrong_length, \%opts) unless $length == $self->is;
  }
}

1;
