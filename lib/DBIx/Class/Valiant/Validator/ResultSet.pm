package DBIx::Class::Valiant::Validator::ResultSet;

use Moo;
use Valiant::I18N;
use Module::Runtime 'use_module';

with 'Valiant::Validator::Each';

has min => (is=>'ro', required=>0, predicate=>'has_min');
has max => (is=>'ro', required=>0, predicate=>'has_max');
has too_few_msg => (is=>'ro', required=>1, default=>sub {_t 'too_few'});
has too_many_msg => (is=>'ro', required=>1, default=>sub {_t 'too_many'});
has invalid_msg => (is=>'ro', required=>1, default=>sub {_t 'invalid'});
has validations => (is=>'ro', required=>1, default=>sub {0});

sub normalize_shortcut {
  my ($class, $arg) = @_;
  if(($arg eq '1') || ($arg eq 'nested')) {
    return { validations => 1 };
  } 
}

sub validate_each {
  my ($self, $record, $attribute, $value, $opts) = @_;

  # If a row is marked to be deleted then don't bother to validate it.
  my @rows = grep { not $_->is_marked_for_deletion } $value->all;
  my $count = scalar(@rows);

  $record->errors->add($attribute, $self->too_few_msg, +{%$opts, count=>$count, min=>$self->min})
    if $self->has_min and $count < $self->min;

  $record->errors->add($attribute, $self->too_many_msg, +{%$opts, count=>$count, max=>$self->max})
    if $self->has_max and $count > $self->max;

  return unless $self->validations;

  my $found_errors = 0;
  foreach my $row (@rows) {
    $row->validate(%$opts);
    $found_errors = 1 if $row->errors->size;
  }
  $record->errors->add($attribute, $self->invalid_msg, $opts) if $found_errors;
}

1;

=head1 TITLE

DBIx::Class::Valiant::Validator::ResultSet - Verify a DBIC related resultset 

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

This validator supports the following attributes:

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
