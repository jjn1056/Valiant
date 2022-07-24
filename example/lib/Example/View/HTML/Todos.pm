package Example::View::HTML::Todos;

use Moose;
use Example::Syntax;
use Valiant::HTML::TagBuilder 'div', 'fieldset', 'table', 'thead','trow', 'tbody', 'td', 'th', 'a', 'b', ':utils';
use Valiant::HTML::Form 'form_for';

extends 'Example::View::HTML';

has 'ctx' => (is=>'ro', required=>1);
has 'list' => (is=>'ro', required=>1, lazy=>1, default=>sub($self) {$self->ctx->controller->list } );
has 'todo' => (is=>'ro', required=>1, lazy=>1, default=>sub($self) {$self->ctx->controller->todo } );

sub render($self, $c) {
  $c->view('HTML::Layout' => page_title=>'Homepage', sub($layout) {
    $c->view('HTML::Navbar' => active_link=>'/todos'),
    form_for $self->todo, +{method=>'POST', style=>'width:35em; margin:auto', csrf_token=>$c->csrf_token }, sub ($fb) {
      fieldset [
        $fb->legend,
        div +{ class=>'form-group' },
          $fb->model_errors(+{class=>'alert alert-danger', role=>'alert'}),

        table +{class=>'table table-striped table-bordered', style=>'margin-bottom:0.5rem'}, [
          thead
            trow [
              th +{scope=>"col"},'Title',
              th +{scope=>"col", style=>'width:6em'}, 'Status',
            ],
          tbody [
            over $self->list, sub ($todo, $i) {
              trow [
               td a +{ href=>"/todos/@{[ $todo->id ]}" }, $todo->title,
               td $todo->status,
              ],
            },
          ],
        ],

        div {style=>'text-align:center; margin-bottom: 1rem'}, [
          a { href=>'todos', style=>'margin: .5rem'}, $self->status_label('all'),
          a { href=>'?status=active', style=>'margin: .5rem'}, $self->status_label('active'),
          a { href=>'?status=completed', style=>'margin: .5rem'}, $self->status_label('completed'),
        ],

        div +{ class=>'form-group' }, [
          $fb->input('title', +{ class=>'form-control', placeholder=>'What needs to be done?', errors_classes=>'is-invalid' }),
          $fb->errors_for('title', +{ class=>'invalid-feedback' }),
        ],
        $fb->submit('Add Todo to List', +{class=>'btn btn-lg btn-primary btn-block'}),
      ],
    }
  });
}

sub status_label($self, $label) {
  return b($label) if $label eq 'all' and !$self->list->status;
  return b($label) if $label eq ($self->list->status||'');
  return $label;
}

__PACKAGE__->meta->make_immutable();
