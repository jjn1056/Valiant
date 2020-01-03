package Valiant::Result;

use Moo;
use Scalar::Util 'blessed';

with 'Valiant::Validatable';

has data => (is=>'ro', required=>1);

sub read_attribute_for_validation {
  my ($self, $attribute) = @_;
  if(ref($self->data) eq 'HASH') {
    if(defined($self->data->{$attribute})) {
      return $self->data->{$attribute};
    } else {
      die "There is no matching attribute '$attribute' in the data";
    }
  } elsif(blessed($self->data) && $self->data->can($attribute)) {
    $self->data->$attribute;
  } else {
    die "can't find $attribute!";
  }
}

# TODO do I really need this...?
sub can { 
  my ($self, $target) = @_;
  if(Scalar::Util::blessed $self->data) {
    if($self->data->can($target)) {
      return 1;
    }
  }
  return 0;
}

sub AUTOLOAD {
  my $self = shift;
  ( my $method = our $AUTOLOAD ) =~ s{.*::}{};

  warn "autoloading $method";

  if(blessed($self->data && $self->data->can($method))) {
    return $self->data->$method(@_);
  }
}

1;

=head1 TITLE

Valiant::Result - Wrap any object or hash into a validatable result object.

=head1 SYNOPSIS


=head1 DESCRIPTION

Create a validation object for a given class or role.  Useful when you need (or prefer)
to build up a validation ruleset in code rather than via the annotations-like approach
given in L<Valiant::Validations>.  Can also be useful to add validations to a class that
isn't Moo/se and can't use  L<Valiant::Validations> or is outside your control (such as
a third party library).  Lastly you may need to build validation sets based on existing
metadata, such as via database introspection or from a file containing validation
instructions.

This uses AUTOLOAD to delegate method calls to the underlying object.

Please note that the code used to create the validation object is not speed optimized so
I recommend you not use this approach in 'hot' code paths.  Its probably best if you can
create all these during your application startup once (for long lived applications).  Maybe
not ideal for 'fire and forget' scripts like cron jobs or CGI.

=head1 ATTRIBUTES

This object has the followed attributes

=head1 data

This is the underlying attribute that contains the object or hash.

=head1 SEE ALSO
 
L<Valiant>, L<Valiant::Validator>, L<Valiant::Validator::Each>.

=head1 AUTHOR
 
See L<Valiant>

=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut
