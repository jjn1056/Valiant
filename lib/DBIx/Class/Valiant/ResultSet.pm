package DBIx::Class::Valiant::ResultSet;

use warnings;
use strict;
use Carp;

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

  # Remove any relationed keys we didn't find with the allows nested
  my @rel_names = $self->result_source->relationships();
  my %found = delete %$fields{@rel_names};
  if(grep { defined $_ } values %found) {
    my $related = join(', ', grep { $found{$_} } keys %found);
    die "You are trying to create a relationship ($related) without setting 'accept_nested_for'";
  }

  my $result = $self->next::method($fields, @args);
  $result->{__VALIANT_CREATE_ARGS}{context} = $context if $context; # Need this for ->insert

  RELATED: foreach my $related(keys %related) {

    if(my $cb = $nested{$related}->{reject_if}) {
      warn "aaaa";
      my $response = $cb->($result, $related{$related});
      next RELATED if $response;
    }

    if(my $limit_proto = $nested{$related}->{limit}) {
      my $limit = (ref($limit_proto)||'' eq 'CODE') ?
        $limit_proto->($self) :
        $limit_proto;
      my $num = scalar @{$related{$related}};
      confess "Relationship $related can't create more than $limit rows at once" if $num > $limit;      
    }

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
