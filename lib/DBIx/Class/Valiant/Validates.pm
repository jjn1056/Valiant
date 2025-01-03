package DBIx::Class::Valiant::Validates;

use Moo::Role;
use Valiant::I18N;
use Scalar::Util;

with 'Valiant::Validates';

around default_validator_namespaces => sub {
  my ($orig, $self, @args) = @_;
  return 'DBIx::Class::Valiant::Validator', $self->$orig(@args);
};

around validate => sub {
  my ($orig, $self, @args) = @_;
  return if $self->{__valiant_add};
  return $self->$orig(@args);
};

1;

=head1 NAME

DBIx::Class::Valiant::Validates - Add Valiant to DBIC

=head1 DESCRIPTION

This is a role which extends L<Valiant::Validates> so that is finds validators
under the L<DBIx::Class::Valiant::Validator> namespace.  It adds this namespace
to the top of the call list, that way we can if needed override core validators
with versions that work properly under L<DBIx::Class>.

You shouldn't need to use this code directly yourself, it gets added automatically
for you.

=head1 SEE ALSO
 
See L<Valiant>, L<DBIx::Class::Valiant>

=head1 AUTHOR

See L<Valiant>.

=head1 COPYRIGHT & LICENSE

See L<Valiant>.

=cut
