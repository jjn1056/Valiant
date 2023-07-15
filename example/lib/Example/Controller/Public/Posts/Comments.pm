package Example::Controller::Public::Posts::Comments;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;
use Types::Standard qw(Int);

extends 'Example::Controller';

## TODO this needs to be fixed, its under public but users $user.  So need to
## not show certain controls if not logged in or something somthing

sub root :At('$path_end/...') Via('../find') ($self, $c, $post) {
  $c->action->next(my $collection = $post->comments); # $post->comments_for($c->user);
}

  sub prepare_build :At('...') Via('root') ($self, $c, $collection) { 
    $self->view_for('build', comment => my $comment = $collection->build({person_id=>$c->user->id}));
    $c->action->next($comment);
  }

    sub build :Get('new') Via('prepare_build') ($self, $c, $comment) {
      return $self->view->set_http_ok;
    }

    sub create :Post('') Via('prepare_build') BodyModel ($self, $c, $comment, $bm) {
      return $comment->set_from_request($bm) ?
        $c->view->set_http_ok : 
          $c->view->set_http_bad_request;
    }

  sub find :At('{:Int}/...') Via('root') ($self, $c, $collection, $id) {
    my $comment = $collection->find({id=>$id}, {prefetch=>'person'}) //
      $c->detach_error(404, +{error=>"Post Id '$id' not found"});
    $c->action->next($comment);
  }

    sub show :Get('') Via('find') ($self, $c, $comment) {
      $self->view(comment => $comment)->set_http_ok;
    }

    sub delete :Delete('') Via('find') ($self, $c, $comment) {
      return $comment->delete && $c->redirect_to_action('../show', [$comment->post_id]);
    }

    sub prepare_edit :At('...') Via('find') ($self, $c, $comment) { 
      $self->view_for('edit', comment => $comment);
      $c->action->next($comment);
    }

      sub edit :Get('edit') Via('prepare_edit') ($self, $c, $comment) {
        return $c->view->set_http_ok;
      }
    
      sub update :Patch('') Via('prepare_edit') BodyModelFor('create') ($self, $c, $comment, $bm) {
        return $comment->set_from_request($bm) ?
          $c->view->set_http_ok :
            $c->view->set_http_bad_request;
      }

__PACKAGE__->meta->make_immutable;
