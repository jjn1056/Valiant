package Valiant::Result::HashRef;

use Moo;
use Scalar::Util 'blessed';

with 'Valiant::Result';

has '+data' => (isa=>sub { ref $_ eq 'HASH' });

sub read_attribute_for_validation {
  my ($self, $attribute) = @_;
  if(exists $self->data->{$attribute}) {
    return  $self->data->{$attribute};
  } else {
    return undef; # TODO Might need a flag to allow die here?
  }
}

sub keys { return keys %{ $_[0]->data } }
sub values { return map { $_[0]->data->{$_} } $_[0]->keys }

1;

=head1 TITLE

Valiant::Result::HashRef - Wrap a hashref in a result object for validation.

=head1 SYNOPSIS

    TBD

=head1 DESCRIPTION

Allows you to run validations against a HashRef.

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
