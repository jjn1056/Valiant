package Example::View::HTML::Contact;

use Moose;
use Example::Syntax;
use Valiant::HTML::TagBuilder 'div', 'fieldset';

extends 'Example::View::HTML';

has 'contact' => (is=>'ro', required=>1);

__PACKAGE__->views(
  layout => 'HTML::Layout',
  navbar => 'HTML::Navbar',
  form => 'HTML::Form',
);

sub render($self, $c) {
  $self->layout(page_title=>'Contact List', sub($layout) {
    $self->navbar(active_link=>'/contacts'),
    $self->form($self->contact, +{style=>'width:35em; margin:auto'}, sub ($fb) {
      fieldset [
        $fb->legend,
        div +{ class=>'form-group' },
          $fb->model_errors(+{class=>'alert alert-danger', role=>'alert'}),
        div +{ class=>'form-group' }, [
          $fb->label('first_name'),
          $fb->input('first_name'),
          $fb->errors_for('first_name'),
        ],
        div +{ class=>'form-group' }, [
          $fb->label('last_name'),
          $fb->input('last_name'),
          $fb->errors_for('last_name'),
        ],
        div +{ class=>'form-group' }, [
          $fb->label('notes'),
          $fb->text_area('notes'),
          $fb->errors_for('notes'),
        ],
        $fb->submit(),
      ],
    }),
  });
}

__PACKAGE__->meta->make_immutable();
