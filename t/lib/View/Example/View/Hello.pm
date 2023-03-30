package View::Example::View::Hello;

use Moo;
use View::Example::View qw(div input hr button_tag form_for);

view layout => 'Layout';
has name => (is=>'ro', required=>1);

sub render {
  my ($self, $c) = @_;
  return layout(page_title => 'Homepage', sub {
    my ($layout) = @_;
    return div +{id=>1}, "hi", 
      div,
      div +{id=>2}, "hello",
      button_tag('fff'),
      hr,
      div +{id=>'morexxx'}, [
        div +{id=>3}, "more",
        div 'none',
        hr +{id=>'hr'},
        div +{id=>4}, "more",
      ],
      div +{id=>3}, sub {
        my ($view) = @_;
        div +{id=>'loop', repeat=>[1,2,3]}, sub {
          my ($view, $item, $idx) = @_;
          div +{id=>$item}, $item;
        },
      },
      form_for('fff', sub {
        my ($fb) = @_;
        $fb->input('foo'),
        $fb->input('bar'),
      }),
      form_for($self, +{}, sub {
        my ($fb) = @_;
        $fb->input('name'),
      });
    });
}

__PACKAGE__->config(
  content_type=>'text/html', 
  status_codes=>[200,201,400])
;
