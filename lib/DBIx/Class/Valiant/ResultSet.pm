package DBIx::Class::Valiant::ResultSet;

use warnings;
use strict;

sub build {
  my ($self, %attrs) = @_;
  return $self->new_result(\%attrs);
}

=head1 DESCRIPTION

=head1 METHODS

This component adds the following methods to your resultset classes.

=head2 build

This just wraps C<new_result> to provide a new result object, optionally
with fields set, that is not yet in storage.  

=head1 AUTHOR
 
John Napiorkowski L<email:jjnapiork@cpan.org>
  
=head1 SEE ALSO
 
L<Valiant>, L<DBIx::Class>

=head1 COPYRIGHT & LICENSE
 
Copyright 2020, John Napiorkowski L<email:jjnapiork@cpan.org>
 
This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
