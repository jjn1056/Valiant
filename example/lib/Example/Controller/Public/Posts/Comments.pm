package Example::Controller::Public::Posts::Comments;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;
use Types::Standard qw(Int);

extends 'Example::Controller';

sub root :Via('../find') At('comments/...') ($self, $c, $post) {
  $c->action->next(my $collection = $post->comments); # $post->comments_for($c->user);
}

  sub prepare_build :Via('root') At('...') ($self, $c, $collection) { 
    $self->view_for('build', comment => my $comment = $collection->build({person_id=>$c->user->id}));
    $c->action->next($comment);
  }

    sub build :GET Via('prepare_build') At('new') ($self, $c, $comment) {
      return $self->view->set_http_ok;
    }

    sub create :POST Via('prepare_build') At('') BodyModel ($self, $c, $comment, $r) {
      $comment->set_from_request($r);
      return $comment->valid ?
        $c->view->set_http_ok : 
          $c->view->set_http_bad_request;
    }

  sub find :Via('root') At('{:Int}/...') ($self, $c, $collection, $id) {
    my $comment = $collection->find({id=>$id}, {prefetch=>'person'}) //
      $c->detach_error(404, +{error=>"Post Id '$id' not found"});
    $c->action->next($comment);
  }

    sub show :GET Via('find') At('') ($self, $c, $comment) {
      $self->view(comment => $comment)->set_http_ok;
    }

    sub delete :DELETE Via('find') At('') ($self, $c, $comment) {
      return $comment->delete && $c->redirect_to_action('../show', [$comment->post_id]);
    }

    sub prepare_edit :Via('find') At('...') ($self, $c, $comment) { 
      $self->view_for('edit', comment => $comment);
      $c->action->next($comment);
    }

      sub edit :GET Via('prepare_edit') At('edit') ($self, $c, $comment) {
        return $c->view->set_http_ok;
      }
    
      sub update :PATCH Via('prepare_edit') At('') BodyModel('~CreateBody') ($self, $c, $comment, $r) {
        $comment->set_from_request($r);
        return $comment->valid ?
          $c->view->set_http_ok :
            $c->view->set_http_bad_request;
      }



__PACKAGE__->meta->make_immutable;
