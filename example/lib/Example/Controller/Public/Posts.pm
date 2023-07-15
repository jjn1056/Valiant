package Example::Controller::Public::Posts;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;
use Types::Standard qw(Int);

extends 'Example::Controller';

sub root :At('$path_prefix/...') Via('/public')  ($self, $c, $user) {
  my $collection = $user->viewable_posts;
  $c->action->next($collection);
}

  sub search :At('/...') Via('root') QueryModel ($self, $c, $collection, $q) {
    my $searched_collection = $collection->filter_by_request($q);
    $c->action->next($searched_collection);
  }

    sub list :Get('') Via('search')  ($self, $c, $collection) {
      return $self->view(list => $collection)->set_http_ok;
    }

  sub find :At('{:Int}/...') Via('root') ($self, $c, $collection, $id) {
    my $post = $collection->find($id, {prefetch=>['author', {comments=>'person'}]}) // 
      $c->detach_error(404, +{error=>"Post Id '$id' not found"});
    $c->action->next($post);
  }

    sub show :Get('') Via('find') ($self, $c, $post) {
      $self->view(post => $post)->set_http_ok;
    }

__PACKAGE__->meta->make_immutable;
