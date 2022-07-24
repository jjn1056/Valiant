package Example::View::HTML::Todos;

use Moose;
use Example::Syntax;
use Valiant::HTML::TagBuilder 'div', 'fieldset', 'table', 'thead','trow', 'tbody', 'td', 'th', 'a', 'b', 'u', ':utils';
use Valiant::HTML::Form 'form_for';

extends 'Example::View::HTML';

has 'list' => (is=>'ro', required=>1, lazy=>1, default=>sub($self) {$self->ctx->controller->list } );
has 'todo' => (is=>'ro', required=>1, lazy=>1, default=>sub($self) {$self->ctx->controller->todo } );
has 'query' => (is=>'ro', required=>1, lazy=>1, default=>sub($self) {$self->ctx->controller->query } );
has 'pager' => (is=>'ro', required=>1, lazy=>1, default=>sub($self) {$self->list->pager } );

sub render($self, $c) {
  $c->view('HTML::Layout' => page_title=>'Homepage', sub($layout) {
    $c->view('HTML::Navbar' => active_link=>'/todos'),
    form_for $self->todo, +{method=>'POST', style=>'width:35em; margin:auto', csrf_token=>$c->csrf_token }, sub ($fb) {
      fieldset [
        $fb->legend,
        div +{ class=>'form-group' }, [
          $fb->model_errors(+{class=>'alert alert-danger', role=>'alert', show_message_on_field_errors=>'Error Adding new Todo'}),
          div {style=>'text-align:center; margin-top:0; margin-bottom: .5rem'}, 
            "@{[ $self->pager->first]} to @{[ $self->pager->last ]} of @{[ $self->pager->total_entries ]}",
        ],



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
            cond {$self->pager->last_page > 1 }
              trow td {colspan=>2, style=>'background:white'},
                [ "Page: ", $self->pagelist ],
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

sub pagelist($self) {
  my @page_html = ();
  foreach my $page (1..$self->pager->last_page) {
    my $query = "?page=${page}";
    $query .= ";status=active" if $self->query->status_active;
    $query .= ";status=completed" if $self->query->status_completed;
    push @page_html, a {href=>$query, style=>'margin: .5rem'}, $page == $self->pager->current_page ? b u $page : $page;
  }
  return @page_html;
}

sub status_label($self, $label) {
  return b u $label if $label eq 'all' and $self->query->status_none;
  return b u $label if $label eq 'active' and $self->query->status_active;
  return b u $label if $label eq 'completed' and $self->query->status_completed;
  return $label;
}

__PACKAGE__->meta->make_immutable();
