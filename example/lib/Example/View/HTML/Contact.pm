package Example::View::HTML::Contact;

use Moose;
use Example::Syntax;
use Valiant::HTML::TagBuilder 'div', 'fieldset', 'a', 'button', ':utils';

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
     cond { $self->contact->validated && !$self->contact->has_errors }
        div +{ class=>'alert alert-success', role=>'alert' }, 'Successfully Saved!',
      fieldset [
        $fb->legend,
        div +{ class=>'form-group' },
          $fb->model_errors(),
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
        a {href=>'/contacts', class=>'btn btn-secondary btn-lg btn-block'}, 'Return to Contact List',
        cond { $self->contact->in_storage }
          button {formaction=>'?x-tunneled-method=delete', formmethod=>'POST', class=>'btn btn-danger btn-lg btn-block'}, 'Delete Contact',
      ],
    }),
  });
}

__PACKAGE__->meta->make_immutable();
