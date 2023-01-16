package Example::View::HTML::Todo;

use Moose;
use Example::Syntax;
use Valiant::HTML::TagBuilder 'div', 'fieldset', 'a';

extends 'Example::View::HTML';

__PACKAGE__->views(
  layout => 'HTML::Layout',
  form_for => 'HTML::FormFor',
  navbar => 'HTML::Navbar',
);

has 'todo' => (is=>'ro', required=>1, handles=>[qw/status_options/] );

sub render($self, $c) {
  $self->layout(page_title=>'Homepage', sub($layout) {
    $self->navbar(active_link=>'/todos'),
    $self->form_for($self->todo, +{style=>'width:35em; margin:auto'}, sub ($ff, $fb, $todo) {
      fieldset [
        div +{ cond=>$fb->successfully_updated, class=>'alert alert-success', role=>'alert' }, 'Successfully Saved!',
        $fb->legend,
        div +{ class=>'form-group' },
          $fb->model_errors(+{show_message_on_field_errors=>'Please fix the listed errors.'}),
        div +{ class=>'form-row' }, [
          div +{ class=>'col form-group col-9' }, [
            $fb->label('title'),
            $fb->input('title'),
            $fb->errors_for('title'),
          ],
          div +{ class=>'col form-group col-3' }, [
            $fb->label('status'),
            $fb->select('status', $self->status_options, +{ include_blank=>1}),
            $fb->errors_for('status'),
          ],
        ],
        $fb->submit('Update Todo'),
        a {href=>$self->link('../list'), class=>'btn btn-secondary btn-lg btn-block'}, 'Return to Todo List',
      ],
    }),
  });
}

__PACKAGE__->meta->make_immutable();
