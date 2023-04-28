package Example::Controller::Public::Posts::Comments;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;
use Types::Standard qw(Int);

extends 'Example::Controller';

sub collection :Via('../entity') At('comments/...') ($self, $c, $post) {
  $c->action->next(my $collection = $post->comments); # $post->comments_for($c->user);
}

  sub new_entity :GET Via('collection') At('/new') ($self, $c, $collection) {
    my $new_entity = $collection->build;
    return $self->view(comment => $new_entity )->set_http_ok;
  }

  sub create :POST Via('collection') At('') BodyModel(CommentBody) ($self, $c, $collection, $r) {
    my $comment = $collection->create(+{person_id=>$c->user->id, %{$r->nested_params}});
    $self->view_for('new_entity', comment => $comment );
    return $comment->valid ?
      $c->view->set_http_ok : 
        $c->view->set_http_bad_request;
  }

  sub entity :Via('collection') At('{:Int}/...') ($self, $c, $collection, $id) {
    my $comment = $collection->find({id=>$id}, {prefetch=>'person'}) //
      $c->detach_error(404, +{error=>"Post Id '$id' not found"});
    $c->action->next($comment);
  }

    sub show :GET Via('entity') At('') ($self, $c, $comment) {
      $self->view(comment => $comment)->set_http_ok;
    }

    sub delete :DELETE Via('entity') At('') ($self, $c, $comment) {
      return $comment->delete && $c->redirect_to_action('../show', [$comment->post_id]);
    }

    sub edit :GET Via('entity') At('edit') ($self, $c, $comment) {
      return $self->view(comment => $comment)->set_http_ok;
    }
  
    sub update :PATCH Via('entity') At('') BodyModel(CommentBody) ($self, $c, $comment, $r) {
      $comment->set_from_request($r);
      $self->view_for('edit', comment => $comment);
      return $comment->valid ?
        $c->view->set_http_ok :
          $c->view->set_http_bad_request;
    }



__PACKAGE__->meta->make_immutable;
