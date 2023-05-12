package Example::Controller::Home;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

## This is an example of how to handle the case when you want the same URL endpoint to
## display one page if the user is logged in and a different one if not.

sub root :Via('../public') At('/...') ($self, $c, $user) { }

  # Nothing here for now so just redirect to login
  sub public_home :GET Via('root') At('') ($self, $c) {
    return $c->redirect_to_action('/session/build') && $c->detach;
  }

  sub user_home :GET Via('root') At('') Does(Authenticated) ($self, $c) {
    return $self->view
      ->add_info("Welcome to your home page!")
      ->add_info('The time is '. localtime); # This is just to show how to use the view object
  }

__PACKAGE__->meta->make_immutable;