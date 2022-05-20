package Example::Controller::Todos;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Catalyst::Controller';

sub root :Chained(/auth) PathPart('todos') Args(0) Does(Verbs) ($self, $c) {
  my $todos = $c->user->todos;
  my $new_todo =  $todos->new_result(+{status=>'active'});
  my $view = $c->view('Components::Todos',
    todos => $todos,
    new_todo => $new_todo);

  use Devel::Dwarn;
  Dwarn +{ $new_todo->get_columns };

  return $new_todo, $view;
}

  sub GET :Action ($self, $c, $new_todo, $view) { return $view->http_ok }

  sub POST :Action ($self, $c, $new_todo, $view) {
    my %params = $c->structured_body(
      ['todo'], 'title', 
    )->to_hash;

    $new_todo->set_columns_recursively(\%params)
      ->insert;

    return $new_todo->valid ?
      $c->redirect_to_action('root')  :
        $view->http_bad_request;
  }

__PACKAGE__->meta->make_immutable;

