package Example::Controller::Posts;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;
use Types::Standard qw(Int);

extends 'Example::Controller';

sub collection :Via('*Private') At('posts/...') ($self, $c, $user) {
  $c->action->next(my $collection = $user->posts);
}

  sub list :Via('collection') At('') QueryModel(PostsQuery) ($self, $c, $collection, $q) {
    my $searched_collection = $collection->filter_by_request($q);
    return $c->view('HTML::Posts', list => $searched_collection)->set_http_ok;
  }

  sub new_entity :GET Via('collection') At('/new') ($self, $c, $collection) {
    my $new_post = $collection->build;
    return $c->view('HTML::Posts::New', post => $new_post )->set_http_ok;
  }

  sub create :POST Via('collection') At('') BodyModel(PostBody) ($self, $c, $collection, $r) {
    my $post_from_request = $collection->new_from_request($r);
    $c->view('HTML::Posts::New', post => $post_from_request );
    return $post_from_request->valid ?
      $c->view->set_http_ok : 
        $c->view->set_http_bad_request;
  }

  sub entity :Via('collection') At('{:Int}/...') ($self, $c, $collection, $id) {
    my $post = $collection->find($id) // $c->detach_error(404, +{error=>"Post Id '$id' not found"});
    $c->action->next($post);
  }

    sub show :GET Via('entity') At('') ($self, $c, $post) {
      $c->view('HTML::Posts::Show', post => $post)->set_http_ok;
    }

    sub delete :DELETE Via('entity') At('') ($self, $c, $post) {
      return $post->delete && $c->redirect_to_action('list');
    }

    sub edit :GET Via('entity') At('edit') ($self, $c, $post) {
      return $c->view('HTML::Posts::Edit', post => $post)->set_http_ok;
    }
  
    sub update :PATCH Via('entity') At('') BodyModel(PostBody) ($self, $c, $post, $r) {
      $post->set_from_request($r);
      $c->view('HTML::Posts::Edit', post => $post);
      return $post->valid ?
        $c->view->set_http_ok :
          $c->view->set_http_bad_request;
    }

__PACKAGE__->meta->make_immutable;
