package Example::HTML::Components::Todos;

use Moo;
use Example::HTML::Components 'Layout', 'FormFor', 'Navbar';
use Valiant::HTML::TagBuilder ':html', ':utils';
use Example::Syntax;

with 'Valiant::HTML::Component';

has 'ctx' => (is=>'ro', required=>1);
has 'list' => (is=>'ro', required=>1, lazy=>1, default=>sub($self) {$self->ctx->user->todos } );
has 'todo' => (is=>'ro', required=>1, lazy=>1, default=>sub($self) {$self->ctx->controller->todo } );

sub render($self) {
  return  Layout 'Todo List',
            Navbar +{active_link=>'/todos'},
            FormFor $self->todo, +{method=>'POST', style=>'width:35em; margin:auto'}, sub ($fb) {
              fieldset [
                $fb->legend,
                div +{ class=>'form-group' },
                  $fb->model_errors(+{class=>'alert alert-danger', role=>'alert'}),

                table +{class=>'table table-striped table-bordered'}, [
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

                div +{ class=>'form-group' }, [
                  $fb->input('title', +{ class=>'form-control', placeholder=>'What needs to be done?', errors_classes=>'is-invalid' }),
                  $fb->errors_for('title', +{ class=>'invalid-feedback' }),
                ],
                $fb->submit('Add Todo to List', +{class=>'btn btn-lg btn-primary btn-block'}),
              ],
            };
}

1;
