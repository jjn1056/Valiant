package Example::Controller::Public::Posts;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;
use Types::Standard qw(Int);

extends 'Example::Controller';

sub collection :Via('*Private') At('public/posts/...') ($self, $c, $user) {
  my $collection = $user->viewable_posts;
  $c->action->next($collection);
}

  sub list :Via('collection') At('') QueryModel(PostsQuery) ($self, $c, $collection, $q) {
    my $searched_collection = $collection->filter_by_request($q);
    return $self->view(list => $searched_collection)->set_http_ok;
  }

  sub entity :Via('collection') At('{:Int}/...') ($self, $c, $collection, $id) {
    my $post = $collection->find($id, {prefetch=>['author', {comments=>'person'}]}) // $c->detach_error(404, +{error=>"Post Id '$id' not found"});
    $c->action->next($post);
  }

    sub show :GET Via('entity') At('') ($self, $c, $post) {
      $self->view(post => $post)->set_http_ok;
    }

__PACKAGE__->meta->make_immutable;
