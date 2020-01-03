package Valiant::Result;

use Moo::Role;

with 'Valiant::Validatable';
requires 'read_attribute_for_validation';

has data => (is=>'ro', required=>1);
has _meta => (is=>'ro', init_arg=>'meta', required=>1);

sub validations { shift->_meta->validations->all } # TODO Probably kill Data::Array

1;

=head1 TITLE

Valiant::Result - Interface to define a Result proxy class.

=head1 SYNOPSIS

    TBD

=head1 DESCRIPTION

Interface that defines a proxy object that wraps underlying data so that it can
collect and set validations.

See L<Valiant::Result::Object> for an example of a concrete class that does this
role and allows you to add validations to any arbitrary object.

=head1 ATTRIBUTES

This object has the followed attributes

=head2 data

This is the underlying attribute that contains the object or hash.

=head2 meta

This is an instance of L<Valiant::Meta> or subclass of.

=head1 SEE ALSO
 
L<Valiant>, L<Valiant::Validator>, L<Valiant::Validator::Each>.

=head1 AUTHOR
 
See L<Valiant>

=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut
