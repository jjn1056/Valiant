package Example::View::HTML::Todo;

use Moose;
use Example::Syntax;
use Valiant::HTML::TagBuilder 'div', 'fieldset';
use Valiant::HTML::Form 'form_for';

extends 'Example::View::HTML';

has 'todo' => (is=>'ro', required=>1, lazy=>1, default=>sub($self) {$self->ctx->controller->todo } );

sub status_options($self) {
  return [qw/
    active
    completed
    archived
  /];
}

sub render($self, $c) {
  $c->view('HTML::Layout' => page_title=>'Homepage', sub($layout) {
    $c->view('HTML::Navbar' => active_link=>'/todos'),
    form_for $self->todo, +{method=>'POST', style=>'width:35em; margin:auto', csrf_token=>$c->csrf_token }, sub ($fb) {
      fieldset [
        $fb->legend,
        div +{ class=>'form-group' },
          $fb->model_errors(+{class=>'alert alert-danger', role=>'alert'}),
          div +{ class=>'form-row' }, [
            div +{ class=>'col form-group' }, [
              $fb->label('title'),
              $fb->input('title', +{ class=>'form-control', errors_classes=>'is-invalid' }),
              $fb->errors_for('ztitleip', +{ class=>'invalid-feedback' }),
            ],
            div +{ class=>'col form-group' }, [
              $fb->label('status'),
              $fb->select('status', $self->status_options, id=>'name', +{ include_blank=>1, class=>'form-control', errors_classes=>'is-invalid'}),
              $fb->errors_for('status', +{ class=>'invalid-feedback' }),
            ],
          ],
        $fb->submit('Update Todo', +{class=>'btn btn-lg btn-primary btn-block'}),
      ],
    },
  });
}

__PACKAGE__->meta->make_immutable();
