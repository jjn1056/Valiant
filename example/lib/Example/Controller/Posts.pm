package Example::Controller::Posts;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;
use Types::Standard qw(Int);

extends 'Example::Controller';

sub root :Via('../protected') At('posts/...') ($self, $c, $user) {
  $c->action->next(my $collection = $user->posts);
}

  sub search :Via('root') At('/...') QueryModel ($self, $c, $collection, $q) {
    my $searched_collection = $collection->filter_by_request($q);
    $c->action->next($searched_collection);
  }

    # GET /posts
    sub list :Via('search') At('') ($self, $c, $collection) {
      return $self->view(list => $collection)->set_http_ok;
    }

  sub prepare_build :Via('root') At('...') ($self, $c, $collection) {
    $self->view_for('build', post => my $post = $collection->build);
    $c->action->next($post);
  }

    # GET /posts/new
    sub build :GET Via('prepare_build') At('new') ($self, $c, $post) {
      return $c->view->set_http_ok;
    }

    # POST /posts
    sub create :POST Via('prepare_build') At('') BodyModel ($self, $c, $post, $r) {
      return $post->set_from_request($r) ?
        $c->view->set_http_ok : 
          $c->view->set_http_bad_request;
    }

  sub find :Via('root') At('{:Int}/...') ($self, $c, $collection, $id) {
    my $post = $collection->find($id) // $c->detach_error(404, +{error=>"Post Id '$id' not found"});
    $c->action->next($post);
  }

    # GET /posts/1
    sub show :GET Via('find') At('') ($self, $c, $post) {
      $self->view(post => $post)->set_http_ok;
    }

    # DELETE /posts/1
    sub delete :DELETE Via('find') At('') ($self, $c, $post) {
      return $post->delete && $c->redirect_to_action('list');
    }

    sub prepare_edit :Via('find') At('...') ($self, $c, $post) { 
      $self->view_for('edit',  post => $post);
      $c->action->next($post);
    }

      # GET /posts/1/edit
      sub edit :GET Via('prepare_edit') At('edit') ($self, $c, $post) {
        return $c->view->set_http_ok;
      }
    
      # PATCH /posts/1
      sub update :PATCH Via('prepare_edit') At('') BodyModel('~CreateBody') ($self, $c, $post, $r) {
        $post->set_from_request($r);
        return $post->valid ?
          $c->view->set_http_ok :
            $c->view->set_http_bad_request;
      }

__PACKAGE__->meta->make_immutable;
