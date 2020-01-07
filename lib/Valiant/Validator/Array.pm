package Valiant::Validator::Array;

use Moo;
use Valiant::I18N;
use Module::Runtime 'use_module';

with 'Valiant::Validator::Each';

has max_length => (is=>'ro', predicate=>'has_max_length');
has min_length => (is=>'ro', predicate=>'has_in_length');
has validations => (is=>'ro', required=>1);
has validator => (is=>'ro', required=>1);

our $meta;

around BUILDARGS => sub {
  my ( $orig, $class, @args ) = @_;
  my $args = $class->$orig(@args);

  if($args->{namespace}) {
    $args->{for} = $args->{namespace};
  }

  if( ((ref($args->{validations})||'') eq 'ARRAY') && !exists $args->{validator} ) {

    my @validations = @{$args->{validations}};
    my $validator = use_module($args->{validator_class}||'Valiant::Class')
      ->new( result_class => 'Valiant::Result::HashRef', %{ $args->{validator_class_args}||+{} },
        for => $args->{for}, 
        validations => [[$args->{attributes} => @validations]]);
    $args->{validator} = $validator;
  }

  return $args;
};

sub validate_each {
  my ($self, $record, $attribute, $value, $options) = @_;
  my %opts = (%{$self->options}, %{$options||{}});
  
  my @values = @$value;
  foreach my $i (0...$#values) {
    my $validator = $self->validator;
    my $result = $validator->validate(+{ $attribute => $values[$i] }, %opts);

    if($result->invalid) {
      #warn $result->errors->full_messages_for($attribute);
      $record->errors->add("${attribute}", $result->errors, +{%opts});
    }
  }

  $record->errors->add("${attribute}", 'generically invalid', +{%opts});

}

1;

=head1 TITLE

Valiant::Validator::Array - Verify items in an arrayref.

=head1 SYNOPSIS

    package Local::Test::Absence;

    use Moo;
    use Valiant::Validations;

    has name => (is=>'ro');

    validates name => ( absence => 1 );

    my $object = Local::Test::Absence->new();
    $object->validate;

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

=head1 SEE ALSO
 
L<Valiant>, L<Valiant::Validator>, L<Valiant::Validator::Each>.

=head1 AUTHOR
 
See L<Valiant>  
    
=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut
