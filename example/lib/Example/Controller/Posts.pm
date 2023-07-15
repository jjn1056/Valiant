package Example::Controller::Posts;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;
use Types::Standard qw(Int);

extends 'Example::Controller';

sub root :At('$path_end/...') Via('../protected') ($self, $c, $user) {
  $c->action->next(my $collection = $user->posts);
}

  sub search :At('/...') Via('root') QueryModel ($self, $c, $collection, $q) {
    my $searched_collection = $collection->filter_by_request($q);
    $c->action->next($searched_collection);
  }

    # GET /posts
    sub list :Get('') Via('search')  ($self, $c, $collection) {
      return $self->view(list => $collection)->set_http_ok;
    }

  sub prepare_build :At('...') Via('root')  ($self, $c, $collection) {
    $self->view_for('build', post => my $post = $collection->build);
    $c->action->next($post);
  }

    # GET /posts/new
    sub build :Get('new') Via('prepare_build') ($self, $c, $post) {
      return $c->view->set_http_ok;
    }

    # POST /posts
    sub create :Post('') Via('prepare_build') BodyModel ($self, $c, $post, $r) {
      return $post->set_from_request($r) ?
        $c->view->set_http_ok : 
          $c->view->set_http_bad_request;
    }

  sub find :At('{:Int}/...') Via('root') ($self, $c, $collection, $id) {
    my $post = $collection->find($id) // $c->detach_error(404, +{error=>"Post Id '$id' not found"});
    $c->action->next($post);
  }

    # GET /posts/1
    sub show :Get('') Via('find') ($self, $c, $post) {
      $self->view(post => $post)->set_http_ok;
    }

    # DELETE /posts/1
    sub delete :Delete('') Via('find') ($self, $c, $post) {
      return $post->delete && $c->redirect_to_action('list');
    }

    sub prepare_edit :At('...') Via('find') ($self, $c, $post) { 
      $self->view_for('edit',  post => $post);
      $c->action->next($post);
    }

      # GET /posts/1/edit
      sub edit :Get('edit') Via('prepare_edit') ($self, $c, $post) {
        return $c->view->set_http_ok;
      }
    
      # PATCH /posts/1
      sub update :Patch('') Via('prepare_edit') BodyModelFor('create') ($self, $c, $post, $r) {
        return $post->set_from_request($r) ?
          $c->view->set_http_ok :
            $c->view->set_http_bad_request;
      }

__PACKAGE__->meta->make_immutable;
