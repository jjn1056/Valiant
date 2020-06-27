package Valiant::Exception::MissingMethod;

use Moo;
extends 'Valiant::Exception';

has object => (is=>'ro', required=>1);
has method => (is=>'ro', required=>1);

sub _build_message {
  my ($self) = @_;
  return "Object '@{[ ref $self->object ]}' has no method '@{[ $self->method ]}'.";
}

1;

=head1 TITLE

Valiant::Exception::MissingMethod - Object is missing method

=head1 SYNOPSIS

    die Valiant::Exception::MissingMethod->new(object=>$self, method=>'if');

=head1 DESCRIPTION

Encapsulates an error when you want to call a method on an object but that object fails
to have that method.

=head1 ATTRIBUTES

=head2 object

=head2 method

The string name of the missing method and a reference to the object that was missing it.

=head2 message

The actual exception message

=head1 SEE ALSO
 
L<Valiant>

=head1 AUTHOR
 
See L<Valiant>

=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut
