package Valiant::Validator::Confirmation;

use Moo;
use Valiant::I18N;

with 'Valiant::Validator::Each';

has confirmation => (is=>'ro', required=>1, default=>sub {_t 'confirmation'});
has suffix => (is=>'ro', required=>1, default=>'_confirmation');

around BUILDARGS => sub {
  my ( $orig, $class, @args ) = @_;
  if(@args == 2 && ref($args[1]) eq 'ARRAY') {
    return +{  attributes => $args[1] }
  }
  return $class->$orig(@args);
};

sub validate_each {
  my ($self, $record, $attribute, $value) = @_;
  my %opts = (%{$self->options});
  my $confirmation_attribute = "${attribute}${\$self->suffix}";
  my $confirmation = $record->can($confirmation_attribute) ||
    die ref($record) . " have not have a method called '$confirmation_attribute'";
  unless($value eq $confirmation->($record)) {
    $record->errors->add($confirmation_attribute, $self->confirmation, +{%opts, attribute=>$attribute})
  }
}

1;

=head1 TITLE

Valiant::Validator::Confirmation - Checks for a 'confirming' attributes equality.

=head1 SYNOPSIS

    package Local::Test::Confirmation;

    use Moo;
    use Valiant::Validations;

    has ['email',
      'email_confirmation'] => (is=>'ro');

    validates email => ( confirmation => 1 );

    my $object = Local::Test::Confirmation->new(
      email => 'AAA@example.com',
      email_confirmation => 'ZZZ@example.com'
    );
    $object->validate; # Returns false

    warn $object->errors->_dump;

    $VAR1 = {
      'email_confirmation' => [
        "Email confirmation doesn't match 'email'",
      ]
    };

=head1 DESCRIPTION

Use this when you have two attributes which should be set to the same value
(for example to confirm someone entered the correct email address or changed
their password to the same value).

The error message (if any) will appear associated with the confirmation attribute.
Error message uses tag C<confirmation> and you can override that with an init arg
of the same name.  You can also change the prefix used to identify the confirming
attribute with the C<prefix> init arg (default value is '_confirmation').

=head1 SHORTCUT FORM

This validator supports the follow shortcut forms:

    validates attribute => ( confirmation => 1, ... );

Which is the same as:

    validates attribute => (
      confirmation => +{},
    );

Not a lot of saved typing but it seems to read better.
 
=head1 GLOBAL PARAMETERS

This validator supports all the standard shared parameters: C<if>, C<unless>,
C<message>, C<strict>, C<allow_undef>, C<allow_blank>.

=head1 AUTHOR
 
John Napiorkowski L<email:jjnapiork@cpan.org>
  
=head1 SEE ALSO
 
L<Valiant>, L<Valiant::Validator>, L<Valiant::Validator::Each>.
    
=head1 COPYRIGHT & LICENSE
 
Copyright 2020, John Napiorkowski L<email:jjnapiork@cpan.org>
 
This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
