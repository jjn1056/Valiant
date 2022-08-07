package Example::View::HTML::Todos;

use Moose;
use Example::Syntax;
use Valiant::HTML::TagBuilder 'div', 'fieldset', 'table', 'thead','trow', 'tbody', 'td', 'th', 'a', 'b', 'u', 'span', ':utils';

extends 'Example::View::HTML';

has 'list' => (is=>'ro', required=>1,  handles=>[qw/query pager/] );
has 'todo' => (is=>'ro', required=>1 );

sub render($self, $c) {
  $c->view('HTML::Layout' => page_title=>'Homepage', sub($layout) {
    $c->view('HTML::Navbar' => active_link=>'/todos'),
    $c->view('HTML::Form', $self->todo, +{style=>'width:35em; margin:auto'}, sub ($fb) {
      fieldset [
        $fb->legend,
        $fb->model_errors(+{
          class=>'alert alert-danger', 
          role=>'alert', 
          show_message_on_field_errors=>'Error Adding new Todo',
        }),

        cond { $self->query->page > $self->pager->last_page}
          div { class=>'alert alert-warning', role=>'alert' },
            "The selected page is greater than the total number of pages available.  Showing the last page.",

        $self->page_window_info,

        table +{class=>'table table-striped table-bordered', style=>'margin-bottom:0.5rem'}, [
          thead
            trow [
              th +{scope=>"col"},'Title',
              th +{scope=>"col", style=>'width:8em'}, 'Status',
            ],
          tbody [
            over $self->list, sub ($todo, $i) {
              trow [
               td a +{ href=>"/todos/@{[ $todo->id ]}" }, $todo->title,
               td $todo->status,
              ],
            },
            cond { $self->pager->last_page > 1  }
              trow td {colspan=>2, style=>'background:white'},
                [ "Page: ", $self->pagelist ],
          ],
        ],
        
        $self->status_filter_box,

        div +{ class=>'form-group' }, [
          $fb->input('title', +{ class=>'form-control', placeholder=>'What needs to be done?', errors_classes=>'is-invalid' }),
          $fb->errors_for('title', +{ class=>'invalid-feedback' }),
        ],
        $fb->submit('Add Todo to List', +{class=>'btn btn-lg btn-primary btn-block'}),
      ],
    }),
  });
}

sub page_window_info($self) {
  cond {$self->pager->total_entries > 0 }
    div {style=>'text-align:center; margin-top:0; margin-bottom: .5rem'}, 
      cond {$self->pager->last_page == 1} 
        "@{[ $self->pager->total_entries ]} @{[ $self->pager->total_entries > 1 ? 'todos':'todo' ]}",
      otherwise 
        "@{[ $self->pager->first]} to @{[ $self->pager->last ]} of @{[ $self->pager->total_entries ]}";
}

sub pagelist($self) {
  my @page_html = ();
  foreach my $page (1..$self->pager->last_page) {
    my $query = "?page=${page};status=@{[ $self->query->status ]}";
    push @page_html, a {href=>$query, style=>'margin: .5rem'}, $page == $self->pager->current_page ? b u $page : $page;
  }
  return @page_html;
}

sub status_filter_box($self) {
  div {style=>'text-align:center; margin-bottom: 1rem'}, [
    map { $self->status_link($_) } qw/all active completed/,
  ];
}

sub status_link($self, $status) {
  my @label = $self->status_label($status);
  return span {style=>'margin: .5rem'}, \@label if $self->query->status eq $status;
  return a { href=>"?status=$status;page=1", style=>'margin: .5rem'}, \@label;
}


sub status_label($self, $status) {
  return b u $status if $status eq $self->query->status;
  return $status;
}

__PACKAGE__->meta->make_immutable();
