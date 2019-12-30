package Valiant::Validator::Format;

use Moo;
use Valiant::I18N;

with 'Valiant::Validator::Each';     

# TODO allow for a number of predefined patterns like alphanum, etc  

has match => (is=>'ro', predicate=>'has_match');
has without => (is=>'ro', predicate=>'has_without');

has invalid_format_match => (is=>'ro', required=>1, default=>sub {_t 'invalid_format_match'});
has invalid_format_without => (is=>'ro', required=>1, default=>sub {_t 'invalid_format_without'});

has exclusion => (is=>'ro', required=>1, default=>sub {_t 'exclusion'});

sub BUILD {
  my ($self, $args) = @_;
  $self->_requires_one_of($args, 'match', 'without');
}

sub normalize_shortcut {
  my ($class, $arg) = @_;
  return +{ match => $arg };
}

sub validate_each {
  my ($self, $record, $attribute, $value) = @_;
  my %opts = (%{$self->options});

  if($self->has_match) {
    my $with = $self->_cb_value($record, $self->match);
    $record->errors->add($attribute, $self->invalid_format_match, \%opts)
      unless $value =~m/$with/;
  }
  if($self->has_without) {
    my $with = $self->_cb_value($record, $self->without);
    $record->errors->add($attribute, $self->invalid_format_without, \%opts)
      if $value =~m/$with/;
  }
}

1;

=head1 TITLE

Valiant::Validator::Format - Validate a value based on a regular expression

=head1 SYNOPSIS

    package Local::Test::Format;

    use Moo;
    use Valiant::Validations;

    has phone => (is=>'ro');
    has name => (is=>'ro');

    validates phone => (
      format => +{
        match => qr/\d\d\d-\d\d\d-\d\d\d\d/,
      },
    );

    validates name => (
      format => +{
        without => qr/\d+/,
      },
    );

    my $object = Local::Test::Format->new(
      phone => '387-1212',
      name => 'jjn1056',
    );

    $object->validate; # Returns false

    warn $object->errors->_dump;

    $VAR1 = {
      'phone' => [
                 'Phone does not match the required pattern'
               ],
      'name' => [
                'Name contains invalid characters'
              ]
    };

=head1 DESCRIPTION

Validates that the attribute value either matches a given regular expression (C<match)
or that it fails to match an exclusion expression (C<without>).

Values that fail the C<match> condition (which can be a regular expression or a
reference to a method that provides one) will add an error matching the tag 
C<invalid_format_match>, which can be overridden as with other tags.

Values that match the C<without> conditions (also either a regular expression or
a coderef that provides one) with all an error matching the tag C<invalid_format_without>
which can also be overridden via a passed parameter.

=head1 SHORTCUT FORM

This validator supports the follow shortcut forms:

    validates attribute => ( format => qr/\d\d\d/, ... );

Which is the same as:

    validates attribute => (
      format => +{
        match => qr/\d\d\d/,
      },
    );

We choose to shortcut the 'match' pattern based on experiene that suggested
it is more common to required a specific pattern than to have an exclusion
pattern.  

This also works for the coderef form.

    validates attribute => ( format => \&pattern, ... );

Which is the same as:

    validates attribute => (
      format => +{
        match => \&pattern,
      },
    );

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
