package DBIx::Class::Valiant::ResultSet;

use warnings;
use strict;

sub build {
  my ($self, %attrs) = @_;
  return $self->new_result(\%attrs);
}

sub new_result {
  my ($self, $fields, @args) = @_;
  my $context = delete $fields->{__context};
  my $result = $self->next::method($fields, @args);
  $result->{__VALIANT_CREATE_ARGS}{context} = $context if $context;
  return $result;
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
