package Valiant::Validator::Result;

use Moo;
use Valiant::I18N;
use Module::Runtime 'use_module';

with 'Valiant::Validator::Each';

has invalid_msg => (is=>'ro', required=>1, default=>sub {_t 'invalid'});
has validations => (is=>'ro', required=>1, default=>sub {0});

sub normalize_shortcut {
  my ($class, $arg) = @_;
  if(($arg eq '1') || ($arg eq 'nested')) {
    return { validations => 1 };
  } 
}

sub validate_each {
  my ($self, $record, $attribute, $result, $opts) = @_;

  # If a row is marked to be deleted then don't bother to validate it.
  return if $result->is_marked_for_deletion;
  return unless $self->validations;

  $result->validate(%$opts);
  $record->errors->add($attribute, $self->invalid_msg, $opts) if $result->invalid;
}

1;

=head1 TITLE

Valiant::Validator::Result - Verify a DBIC related result

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

This validator supports the following attributes:

=head2 invalid_msg

String or translation tag of the error when the result is not valid.

=head1 SHORTCUT FORM

This validator supports the follow shortcut forms:

=head1 GLOBAL PARAMETERS

This validator supports all the standard shared parameters: C<if>, C<unless>,
C<message>, C<strict>, C<allow_undef>, C<allow_blank>.

=head1 SEE ALSO
 
L<Valiant>, L<Valiant::Validator>, L<Valiant::Validator::Each>.

=head1 AUTHOR
 
See L<Valiant>  
    
=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut
