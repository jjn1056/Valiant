package Example::View::HTML::Contact;

use Moo;
use Example::Syntax;
use Example::View::HTML
  -tags => qw(div a fieldset legend br button form_for),
  -views => 'HTML::Layout', 'HTML::Navbar';

has 'contact' => (is=>'ro', required=>1);

sub render($self, $c) {
  html_layout page_title=>'Contact List', sub($layout) {
    html_navbar active_link=>'/contacts',
    form_for $self->contact, +{style=>'width:35em; margin:auto'}, sub ($fb, $contact) {
      div +{ if=>$fb->successfully_updated, class=>'alert alert-success', role=>'alert' }, 'Successfully Saved!',

      fieldset [
        $fb->legend,
        div +{ class=>'form-group' },
          $fb->model_errors({show_message_on_field_errors=>'Please fix the listed errors.'}),
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
      ],

      fieldset [
        div +{ class=>'form-group' }, [
          $fb->errors_for('emails'),
          $fb->fields_for('emails', sub($fb_e, $e) {
            $fb_e->legend,
            div +{ class=>'form-row' }, [
              div +{ class=>'col form-group' }, [
                $fb_e->label('address'),
                $fb_e->input('address'),
                $fb_e->errors_for('address'),
              ],
              div +{ class=>'col form-group col-2' }, [
                $fb_e->label('_delete'), br,
                $fb_e->checkbox('_delete'),
              ],
            ]
          }, sub ($fb_final, $new_e) {
            $fb_final->button( '_add', 'Add Email Address');
          }),
        ],
      ],

      fieldset [
        div +{ class=>'form-group' }, [
          $fb->errors_for('phones'),
          $fb->fields_for('phones', sub($fb_e, $e) {
            $fb_e->legend,
            div +{ class=>'form-row' }, [
              div +{ class=>'col form-group' }, [
                $fb_e->label('phone_number'),
                $fb_e->input('phone_number'),
                $fb_e->errors_for('phone_number'),
              ],
              div +{ class=>'col form-group col-2' }, [
                $fb_e->label('_delete'), br,
                $fb_e->checkbox('_delete'),
              ],
            ]
          }, sub ($fb_final, $new_e) {
            $fb_final->button( '_add', 'Add Phone Number');
          }),
        ],
      ],

      $fb->submit(),
      a {href=>'/contacts', class=>'btn btn-secondary btn-lg btn-block'}, 'Return to Contact List',
      button {
        cond=>$contact->in_storage, 
        formaction=>'?x-tunneled-method=delete',
        formmethod=>'POST',
        class=>'btn btn-danger btn-lg btn-block'
      }, 'Delete Contact',
    },
  };
}

1;