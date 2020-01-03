package Valiant::Class;

use Moo;
use Module::Runtime 'use_module';

with 'Valiant::Validatable';

has _validates => (
  is=>'ro',
  required=>1,
  init_arg=>'validates');

has meta_class => (is=>'ro', required=>1, default=>'Valiant::Meta');

has _meta => (
  is=>'ro',
  require=>1,
  lazy=>1,
  builder=>'_build_meta'.
);

  sub _build_meta {
    my $self = shift;
    my $meta = use_module($self->meta_class)->new(target=>ref($self)); ## TODO this isn't right...
  }

sub validates {
  my $self = shift;
  $self->_meta->validates(@_);

  return $self;
}

1;

=head1 TITLE

Valiant::Class - Create a validation ruleset dynamically

=head1 SYNOPSIS

    $validator->validate(
      Valiant::Result->new($user)
    );

    package Local::MyApp;

    use Valiant::Class;
    use Types::Standard 'Int';

    my $validator = Valiant::Class->new(
                      isa => 'MyApp::User', # or does => \@list_of_roles
                      namespace => ['Local::MyApp::Validators', 'Local::Shared::Validators'],
                      validates => [
                        sub {
                          my $user = shift;
                          unless($user->is_active) {
                            $user->errors->add(_base=>'Cannot change inactive user');
                          }
                        },
                        username => {
                          length => [2,20],
                          format => qr/^[a-zA-Z0-9_]*$/,
                          presense => 1,
                        },
                        password => [
                          presence => 1,
                          length => [8,24],
                          confirmation => 1,
                          with => {
                            method => 'password_not_in_history',
                            message_if_false => 'Cannot reuse an old password',
                          },
                        ],
                        age => [
                          Int->where('$_ >= 18'), +{
                            message => 'You must be 18 years old to register',
                          },
                        ],
                      ],
                    );

    if(my $result = $validator->validate($user)) {
      # Do something with the errors...
    }

=head1 DESCRIPTION

Create a validation object for a given class or role.  Useful when you need (or prefer)
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

=head1 validators

=head1 isa

=head2 does

=head2 namespace

=head1 SEE ALSO
 
L<Valiant>, L<Valiant::Validator>, L<Valiant::Validator::Each>.

=head1 AUTHOR
 
See L<Valiant>

=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut
