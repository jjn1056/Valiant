package DBIx::Class::Valiant::Validator::Result;

use Moo;
use Valiant::I18N;

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

  unless(defined $result) {
    my $rel_data = $record->relationship_info($attribute);
    if($rel_data->{attrs}{accessor} eq 'single' && $rel_data->{attrs}{join_type} eq 'LEFT') {
      # Its an optional relation like 'might have' so its not an error to be undefined.
      return;
    } else {
      $record->errors->add($attribute, $self->invalid_msg, $opts);
      return;
    }
  }

  # If a row is marked to be deleted then don't bother to validate it.
  return if $result->is_marked_for_deletion;
  return unless $self->validations;

  $result->validate(%$opts); # unless $result->validated
  $record->errors->add($attribute, $self->invalid_msg, $opts) if $result->invalid;

  # Not sure if this should be default behavior or not...
  $result->errors->each(sub {
    my ($attr, $message) = @_;
    $record->errors->add("${attribute}.${attr}", $message);
  });

}

1;

=head1 TITLE

DBIx::Class::Valiant::Validator::Result - Verify a DBIC related result

=head1 SYNOPSIS

    package Example::Schema::Result::Person;

    use base 'Example::Schema::Result';

    __PACKAGE__->load_components(qw/
      Valiant::Result
      Core
    /);

    __PACKAGE__->table("person");

    __PACKAGE__->add_columns(
      id => { data_type => 'bigint', is_nullable => 0, is_auto_increment => 1 },
      username => { data_type => 'varchar', is_nullable => 0, size => 48 },
      first_name => { data_type => 'varchar', is_nullable => 0, size => 24 },
      last_name => { data_type => 'varchar', is_nullable => 0, size => 48 },
      password => {
        data_type => 'varchar',
        is_nullable => 0,
        size => 64,
      },
    );

    __PACKAGE__->might_have(
      profile =>
      'Example::Schema::Result::Profile',
      { 'foreign.person_id' => 'self.id' }
    );

    __PACKAGE__->validates(profile => (result=>+{validations=>1}, on=>'profile' ));


=head1 DESCRIPTION

Trigger validations on a related result.

=head1 ATTRIBUTES

This validator supports the following attributes:

=head2 validations

Boolean.  Default is 0 ('false').  Used to trigger validations on the related result.

Please keep in mind these errors will be localized to the associated object, not on the current
object.

=head2 invalid_msg

String or translation tag of the error when the result is not valid.

=head1 SHORTCUT FORM

This validator supports the follow shortcut forms:

    validates attribute => ( result => 1, ... );

Which is the same as:

    validates attribute => (
      result => {
        validations => 1,
      }
    );

Which is a shortcut when you wish to run validations on the related rows

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
