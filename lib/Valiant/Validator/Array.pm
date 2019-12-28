package Valiant::Validator::Array;

use Moo;
use Valiant::I18N;
use Valiant::Result;
use Valiant::Meta;

with 'Valiant::Validator::Each';

has max_length => (is=>'ro', predicate=>'has_max_length');
has validates => (is=>'ro', requires=> 1);
#has is_present => (is=>'ro', required=>1, default=>sub {_t 'is_present'});

our $meta;

sub BUILD {
  my ($self, $args) = @_;
  $meta = Valiant::Meta->new(target=>ref($self));
  $meta->validates($self->attributes, @{$self->validates});
}

sub validate_each {
  my ($self, $record, $attribute, $value) = @_;
  my %opts = (%{$self->options});
  my @values = @$value;
    use Devel::Dwarn;

  foreach my $i (0...$#values) {
    my $result = Valiant::Result->new(data=>+{$attribute=>$values[$i]});
    unless($meta->validate($result)) {
      #Dwarn $result->errors->to_hash(full_messages=>1);
      foreach my $err (@{$result->errors->details->{$attribute}}) {
        my $message = delete $err->{error};
        $record->errors->add("${attribute}.$i", $message, +{%opts, %$err});


      }

    }
  }

  # Dwarn $record;
  #Dwarn $value;

  #$record->errors->add($attribute, $self->is_present, \%opts)
}

1;

__END__

around BUILDARGS => sub {
  my ( $orig, $class, @args ) = @_;

  use Devel::Dwarn;
  Dwarn \@args;

  if(@args == 2 && ref($args[1]) eq 'ARRAY') {
    return +{  attributes => $args[1] }
  }
  return $class->$orig(@args);
};


=head1 TITLE

Valiant::Validator::Array - Verify items in an arrayref.

=head1 SYNOPSIS

    package Local::Test::Absence;

    use Moo;
    use Valiant::Validations;

    has name => (is=>'ro');

    validates name => ( absence => 1 );

    my $object = Local::Test::Absence->new();
    $object->validate; # Returns false

    warn $object->errors->_dump;

    $VAR1 = {
      'name' => [
        'Name must be blank',
      ]
    };

=head1 DESCRIPTION

Value must be absent (undefined, an empty string or a string composed
only of whitespace). Uses C<is_present> as the translation tag and you can set 
that to override the message.

=head1 SHORTCUT FORM

This validator supports the follow shortcut forms:

    validates attribute => ( absence => 1, ... );

Which is the same as:

    validates attribute => (
      absence => +{},
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
