package Example::View::HTML::Todos::Todo;

use Moo;
use Example::Syntax;
use Example::View::HTML
  -tags => qw(div a fieldset form_for),
  -util => qw(path),
  -views => 'HTML::Page', 'HTML::Navbar';

has 'todo' => (is=>'ro', required=>1, handles=>[qw/status_options/] );

sub render($self, $c) {
  html_page page_title=>'Homepage', sub($layout) {
    html_navbar active_link=>'/todos',
    div +{ class=>'col-5 mx-auto' },
    form_for $self->todo, +{action=>path('edit')}, sub ($self, $fb, $todo) {
      fieldset [
        div +{ if=>$fb->successfully_updated, class=>'alert alert-success', role=>'alert' }, 'Successfully Saved!',
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
        a {href=>path('../list'), class=>'btn btn-secondary btn-lg btn-block'}, 'Return to Todo List',
      ],
    },
  };
}

1;