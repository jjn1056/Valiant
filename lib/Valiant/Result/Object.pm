package Valiant::Result::Object;

use Moo;
use Scalar::Util 'blessed';

with 'Valiant::Result';

has '+data' => (isa=>sub { blessed $_ });

sub read_attribute_for_validation {
  my ($self, $attribute) = @_;
  if($self->data->can($attribute)) {
    return $self->data->$attribute;
  } else {
    die "${\$self->data} cannot provide '$attribute'";
  }
}

sub AUTOLOAD {
  my $self = shift;
  ( my $method = our $AUTOLOAD ) =~ s{.*::}{};

  if(blessed($self->data) && $self->data->can($method)) {
    return $self->data->$method(@_);
  } else {
    # warn "cannot find $method in ${\$self->data}";
  }
}

1;

=head1 TITLE

Valiant::Result::Object - Wrap any object into a validatable result object.

=head1 SYNOPSIS

    TBD

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

You probably won't use this directly (although you can) since we have L<Valiant::Class> to
encapsulate the most common patterns for this need.

=head1 SEE ALSO

This does the interface defined by L<Valiant::Result> so see the docs on that.
 
Also: L<Valiant>, L<Valiant::Validator>, L<Valiant::Validator::Each>.

=head1 AUTHOR
 
See L<Valiant>

=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut
