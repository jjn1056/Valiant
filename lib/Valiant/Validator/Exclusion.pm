package Valiant::Validator::Exclusion;

use Moo;
use Valiant::I18N;

with 'Valiant::Validator::Each';

has in => (is=>'ro', required=>1);
has exclusion => (is=>'ro', required=>1, default=>sub {_t 'exclusion'});

around BUILDARGS => sub {
  my ( $orig, $class, @args ) = @_;
  if(@args == 2 && ref($args[1]) eq 'ARRAY') {
    return +{ in => $args[0], attributes => $args[1] }
  }
  return $class->$orig(@args);
};

sub validate_each {
  my ($self, $record, $attribute, $value) = @_;

  my $in = $self->in;
  my @in = ();
  if(ref($in) eq 'CODE') {
    @in = $in->($record);
  } else {
    @in = @$in;
  }

  my %opts = (%{$self->options}, list=>\@in);

  if(grep { $_ eq $value } @in) {
    $record->errors->add($attribute, $self->exclusion, \%opts)
  }
}

1;

=head1 TITLE

Valiant::Validator::Exclusion - Value cannot be in a list

=head1 SYNOPSIS

    package Local::Test::Exclusion;

    use Moo;
    use Valiant::Validations;

    has domain => (is=>'ro');
    has country => (is=>'ro');

    validates domain => (
      exclusion => +{
        in => [qw/org co/],
      },
    );

    validates country => (
      inclusion => +{
        in => \&restricted,
      },
    );

    sub restricted {
      my $self = shift;
      return (qw(usa uk));
    }

    my $object = Local::Test::Exclusion->new(
      domain => 'org',
      country => 'usa',
    );

    $object->validate; # Returns false

    warn $object->errors->_dump;

    $VAR1 = {
      'country' => [
        'Country is reserved'
      ],
      'domain' => [
        'Domain is reserved'
      ]
    };

=head1 DESCRIPTION

Value cannot be from a list of reserved values.  Value can be given
as either an arrayref or a coderef (which recieves the validating 
object as the first argument, so you can call methods for example).

If value is invalid uses the C<exclusion> translation tag (which you can
override as an argument).

=head1 SHORTCUT FORM

This validator supports the follow shortcut forms:

    validates attribute => ( exclusion => [qw/a b c/], ... );

Which is the same as:

    validates attribute => (
      exclusion => +{
        in => [qw/a b c/],
      },
    );

This also works for the coderef form:

    validates attribute => ( exclusion => \&coderef, ... );

    validates attribute => (
      exclusion => +{
        in => \&coderef,
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
