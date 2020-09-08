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

  my %related = ();
  my %nested = $self->result_class->accept_nested_for;
  
  foreach my $associated (keys %nested) {
    $related{$associated} = delete($fields->{$associated})
      if exists($fields->{$associated});
  }

  my $result = $self->next::method($fields, @args);
  $result->{__VALIANT_CREATE_ARGS}{context} = $context if $context; # Need this for ->insert

  foreach my $related(keys %related) {
    $result->set_related_from_params($related, $related{$related});
  }

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
