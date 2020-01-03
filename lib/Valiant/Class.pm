package Valiant::Class;

use Moo;
use Module::Runtime 'use_module';

has for => (is=>'ro', required=>1);
has result_class => (is=>'ro', required=>1, default=>'Valiant::Result::Object');
has meta_class => (is=>'ro', required=>1, default=>'Valiant::Meta');
has validations => (
  is=>'ro',
  required=>1,
  default=>sub { [] }); # Allow for using ->validates  

has _meta => (
  is=>'ro',
  require=>1,
  lazy=>1,
  builder=>'_build_meta'
);

  sub _build_meta {
    my $self = shift;
    my $meta = use_module($self->meta_class)
      ->new(target=>ref($self->for));
  }

sub BUILD {
  my $self = shift;
  foreach my $rules(@{ $self->validations }) {
    ## TODO this coould be more sophisticated to allow
    ## less refs insides of refs (not sure if thats a good
    ## or not.
    $self->_meta->validates(@$rules);
  }
}

sub validates {
  my ($self, @rules) = @_;
  $self->_meta->validates(@rules);
  return $self;
}

sub validates_with {
  my ($self, @rules) = @_;
  $self->_meta->validates_with(@rules);
  return $self;
}

sub validate {
  my ($self, $target, @validate_options) = @_;
  my $result = use_module($self->result_class)
    ->new(data=>$target, meta=>$self->_meta);

  $result->validate(@validate_options);
  return $result;
}

1;

=head1 TITLE

Valiant::Class - Create a validation ruleset dynamically

=head1 SYNOPSIS

    my $validator = Valiant::Class->new(
      for => 'Local::User',
      validations => [
        [ sub { unless($_[0]->is_active) { $_[0]->errors->add(_base=>'Cannot change inactive user') } } ],
        [ name => length => [2,15], format => qr/[a-zA-Z ]+/ ],
        [ age => numericality => 'positive_integer' ],
      ]
    );

You can also call an API to add validation rules

    $validator
      ->validates(name => length => [2,15], format => qr/[a-zA-Z ]+/)
      ->validates(age => numericality => 'positive_integer')
      ->validates_with('UserValidator'); # Calls Local::Test::User::UserValidator

Then runs validation on it with an instance of a concrete class
that has no validation rules of its own:

    package Local::Test::User {

      use Moo;

      has ['name', 'age', 'is_active'],
        is=>'ro',
        required=>1;
    }

    # A user with several validation issues
    my $user = Local::Test::User->new(
      name=>'01', 
      age=>-15,
      is_active=>0);

    my $result = $validator->validate($user);

    $result->invalid; # TRUE

    warn $result->errors->_dump;

    $VAR = {
      '_base' => [
                   'Cannot change inactive user'
                 ],
      'age' => [
                 'Age must be greater than or equal to '
               ],
      'name' => [
                  'Name does not match the required pattern'
                ] 
    };

=head1 DESCRIPTION

Create a validation runner for a given class or role.  Useful when you need (or prefer)
to build up a validation ruleset in code rather than via the annotations-like approach
given in L<Valiant::Validations>.  Can also be useful to add validations to a class that
isn't Moo/se and can't use  L<Valiant::Validations> or is outside your control (such as
a third party library).  Lastly you may need to build validation sets based on existing
metadata, such as via database introspection or from a file containing validation
instructions.

Please note that the code used to create the validation object is not speed optimized so
I recommend you not use this approach in 'hot' code paths.  Its probably best if you can
create all these during your application startup once (for long lived applications).  Maybe
not ideal for 'fire and forget' scripts like cron jobs or CGI.

=head1 ATTRIBUTES

This object has the followed attributes

=head2 for

The class this validator is for.  Used to load locale files and to look for custom
validation objects.  Should something that ISA or DOES of the class that you are going
to run validations on (this currently isnt enforced but please to rely on that).

=head2 result_class

Defaults to L<Valiant::Result::Object>.  Needs to be something that does L<Valiant::Result>.
Write your own if you have an object with unusual attribute accessors.

=head2 meta_class

Defaults to L<Valiant::Meta>.  Should be something that is a subclass of that.  You
probably won't overrride this unless you are doing extremely odd stuff.

=head2 validations

Should be an arrayref of validation rules, where each rule is an arrayref containing
the rules (where the rules are anything you'd pass to C<validates> in L<Valiant::Validations>

=head1 METHODS

This class does the following methods

=head2 validate

Given an instance of the object to be validated, return a result objects that wraps it
and provides any validation errors.

=head2 validates

Adds validation rules.

=head2 validates_with

Adds a validation object.

=head1 SEE ALSO
 
L<Valiant>, L<Valiant::Validator>, L<Valiant::Validator::Each>.

=head1 AUTHOR
 
See L<Valiant>

=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut
