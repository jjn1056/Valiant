use Test::Most;

{
  package Valiant::HTML::Components;

  use Moo;
  use Module::Runtime 'use_module';
  use Moo::_Utils;
  require Sub::Util;

  has _components => (is=>'ro', required=>1, init_arg=>undef, default=>sub { +{} });

  my $_self;
  sub BUILD {
    my $self = shift;
    $_self ||= $self;
  }

  sub import {
    my $class = shift;
    my $target = caller;

    foreach my $component (@_) {
      Moo::_Utils::_install_tracked($target, $component, sub {
        my @args = @_;
        my $attrs = (ref($args[0])||'') eq 'HASH' ? shift(@args) : +{};
        my $content = shift(@args) if $_self->has_content($component);
        my $component = $_self->get( $component, $attrs, $content);

        return ($component, @args) if @args;
        return $component;
      });
    }
  }
  
  sub add {
    my ($self, $comp_name, $args) = @_;
    die "Component '$comp_name' already added" if exists $self->_components->{$comp_name};
    use_module($args->{class});
    return $self->_components->{$comp_name} = $args;
  }

  sub get {
    my ($self, $comp_name, $args, $inner) = @_;
    my $component_args = $self->_components->{$comp_name} || die "Component '$comp_name' does not exist";

    my $class = $component_args->{class};
    my $init = $component_args->{constructor} ||= sub {
      my ($class, %args) = @_;
      return $class->new(%args);
    };

    return my $component = $init->($class, %$args, (defined($inner) ? (content => $inner) : ()));
  }

  sub has_content {
    my ($self, $comp_name) = @_;
    my $component_args = $self->_components->{$comp_name} || die "Component '$comp_name' does not exist";
    return $component_args->{class}->can('content') ? 1:0;
  }

  package Valiant::HTML::Component;

  use Moo::Role;
  use Valiant::HTML::TagBuilder;
  use Valiant::HTML::SafeString 'concat';

  requires 'render';

  around render => sub {
    my ($orig, $self) = (shift, shift);
    my @args = $self->prepare_render_args(@_);
    my @rendered = map {
      $_->can('render') ? $_->render : $_;
    } $self->$orig(@args);

    return concat(@rendered);
  };

  sub prepare_render_args {
    my ($self, @args) = @_;
    return @args;
  }

  package Valiant::HTML::ContentComponent;

  use Moo::Role;
  use Valiant::HTML::SafeString 'concat';
  use Scalar::Util 'blessed';

  requires 'render';

  has content => (is=>'ro', predicate=>'has_content');

  around render => sub {
    my ($orig, $self) = (shift, shift);
    my @args = $self->prepare_render_args(@_);
    my @rendered = map {
      $_->can('render') ? $_->render : $_;
    } $self->$orig(@args);

    return concat(@rendered);
  };

  sub prepare_render_args {
    my ($self, @args) = @_;
    my $content = $self->expand_content;
    return $content ? ( $content, @args) : @args;
  }

  sub expand_content {
    my $self = shift;
    return unless $self->has_content;

    my $content = $self->content;
    my @content = ();
    if((ref($content)||'') eq 'CODE') {
      @content = $content->($self->content_args);
    } elsif((ref(\$content)||'') eq 'SCALAR') {
      @content = ($content);
    } elsif((ref($content)||'') eq 'ARRAY') {
      @content = @$content;
    }

    return concat map { 
      (blessed($_) && $_->can('render')) ? 
        $_->render : 
        $_
      } @content;
  }
  
  sub content_args {
    my $self = shift;
    return $self;
  }

  use Moo::Role;

  package Local::Template::Hello;

  use Moo;
  use Valiant::HTML::TagBuilder 'p';

  with 'Valiant::HTML::Component';

  has 'name' => (is=>'ro', required=>1);

  sub render {
    my ($self) = @_;
    return p "Hello @{[ $self->name ]}";
  }

  package Local::Template::Page;

  use Moo;
  use Valiant::HTML::Components 'Hello', 'Layout';
  use Valiant::HTML::TagBuilder 'p';

  with 'Valiant::HTML::Component';

  has 'name' => (is=>'ro', required=>1);

  sub render {
    my ($self) = @_;
    return  Layout +{ page_title=>'Layout1' }, sub {
              shift->top(
                p [
                  p 111,
                  p 222,
                ]
              );
              return Hello +{ name=>$self->name },
              p +{ id=>1 },
              "Truth! Justice!";
    };
  }

  package Local::Template::Page2;

  use Moo;
  use Valiant::HTML::Components 'Layout';
  use Valiant::HTML::TagBuilder 'p';

  with 'Valiant::HTML::Component';

  sub render {
    my ($self) = @_;
    return  Layout +{ page_title=>'Layout2' }, 'fffffff';
  }

  package Local::Template::Page3;

  use Moo;
  use Valiant::HTML::Components 'Layout';
  use Valiant::HTML::TagBuilder 'p';

  with 'Valiant::HTML::Component';

  sub render {
    my ($self) = @_;
    my $html = Layout +{ page_title=>'Layout2' }, [
      p '111',
      p '222',
      p '333',
    ];

    $html->page_title('Layout3');
    return $html;
  }

  package Local::Template::Layout;

  use Moo;
  use Valiant::HTML::TagBuilder ':html';

  with 'Valiant::HTML::ContentComponent';

  has 'page_title' => (is=>'rw', required=>1);
  has 'top' => (is=>'rw', required=>1, default=>sub { "test<p>" });

  sub render {
    my ($self, $inner) = @_;
    return  html [
              $self->top,
              head
                title $self->page_title,
              body $inner
            ];
  }
}

my $registry = Valiant::HTML::Components->new;
ok $registry->add(Hello => +{class=>'Local::Template::Hello'});
ok $registry->add(Page => +{class=>'Local::Template::Page'});
ok $registry->add(Page2 => +{class=>'Local::Template::Page2'});
ok $registry->add(Page3 => +{class=>'Local::Template::Page3'});

ok $registry->add(Layout => +{class=>'Local::Template::Layout'});

use Devel::Dwarn;
#Dwarn $registry->get(Page => +{name=>'John'});
#Dwarn $registry->get(Page => +{name=>'John'})->render;

warn $registry->get(Page => +{name=>'John'})->render;
warn $registry->get(Page2 => +{})->render;
warn $registry->get(Page3 => +{})->render;

done_testing;

__END__


use Devel::Dwarn;



use Devel::Dwarn;

warn '.......';

warn div "hello";

warn div +{id=>'one'},
  div 'hello';

warn hr {id=>'rule'},
  div 'hi',
  div sub {
    hr,
    div div div 'inner<a>dddd</a>',
    div 'last';
  },
  div 'f',
  div [
    div 1,
    div 2,
  ];

warn hr 'fff';
warn hr {id=>3}, 'inner';
warn hr {id=>1}, '111', hr '2222';
warn hr sub { 'aaaa', hr 'fff' }, hr '333';
warn hr {id=>1}, hr '2222';

use Valiant::HTML::Components ':html', 
  ':flow-control', 
  'Layout', 
  'Form';

sub render($self) {
  return Layout +{ title=>$self->title }, sub {
    return Form +{ model=>$self->person, method=>'POST' }, sub($form) {
      check $self->title eq 'ddd', sub { ... },
      include 'external_template', \%args,
      fieldset sub {
        legend 'Sign In',
        div +{ class=>'form-group' },
          $form->model_errors(+{class=>'alert alert-danger', role=>'alert'}),
        div +{ class=>'form-group' },
          $form->label('username') +
          $form->input('username', { class=>'form-control' }),
      }
    }
  };
}




{
  package Valiant::HTML::ComponentRegistry;

  use Moo;
  use Module::Runtime 'use_module';
  use Valiant::HTML::TagBuilder ':all';

  has _factory_class => (is=>'ro', required=>1, init_arg=>'factory_class', default=>sub { 'Valiant::HTML::ComponentFactory' });
  has _components => (is=>'ro', required=>1, init_arg=>undef, default=>sub { +{} });

  my $_self;
  sub BUILD {
    my $self = shift;
    $_self ||= $self;
  }

  sub element {
    my ($self, $tag, $attrs, @children) = @_;
  }

  sub add_component {
    my ($self, $comp_name, $factory_args) = @_;
    die "Component '$comp_name' already added" if exists $self->_components->{$comp_name};
    return $self->_components->{$comp_name} = $self->new_factory(%$factory_args, registry=>$self);
  }

  sub get_component {
    my ($self, $comp_name, $args, $inner) = @_;
    my $component_factory = $self->_components->{$comp_name} || die "Component '$comp_name' does not exist";
    my $component = $component_factory->create(%$args, (defined($inner) ? (content => $inner) : ()));
    return $component;
  }

{
  package Valiant::HTML::Element;

  use Moo;

  has 'type' => (is=>'ro', required=>1);
  has 'props' => (is=>'ro', required=>1);
  has 'children' => (is=>'ro', required=>1);  # Arrayref of string|ElementObjInstance|coderef


  package Valiant::HTML::ComponentFactory;

  use Moo; 
  use Valiant::HTML::SafeString 'concat';

  has class => (is=>'ro', required=>1);
  has constructor => (is=>'ro', lazy=>1, required=>1, builder=>'_build_constructor' );
  has registry => (is=>'ro', required=>1);

  sub _build_constructor {
    return sub {
      my ($self, $class, %args) = @_;
      return $class->new(%args, registry=>$self->registry);
    };
  }

  has _init_args => (is=>'ro', init_args=>'init_args', predicate=>'has_init_args');

  sub get_init_args {
    my $self = shift;
    return $self->has_init_args ? %{$self->_init_args} : ();
  }

  sub prepare_args {
    my ($self, %args) = @_;
    %args = ($self->get_init_args, %args);
    return %args;
  }

  sub create {
    my $self = shift;
    my %args = $self->prepare_args(@_);
    my $component = $self->constructor->($self, $self->class, %args);
    return $component;
  }



  use Module::Runtime 'use_module';

  has factory_class => (is=>'ro', required=>1, default=>sub { 'Valiant::HTML::ComponentFactory' });

  sub new_factory {
    my ($self, %args) = @_;
    return use_module($self->factory_class)->new(%args);
  }



  sub render_component {
    my $self = shift;
    my $component = $self->get_component(@_);
    return $component->render;
  }
}

ok my $registry = Valiant::HTML::ComponentRegistry->new;
ok $registry->add_component(Hello => +{class=>'Local::Template::Hello'});

__END__


{
  package Valiant::HTML::Component;

  use Moo::Role;
  use Valiant::HTML::TagBuilder;
  use Valiant::HTML::SafeString;
  
  sub safe { shift; return Valiant::HTML::SafeString::safe(@_); }
  sub raw { shift; return Valiant::HTML::SafeString::raw(@_); }
  sub concat { shift; return Valiant::HTML::SafeString::concat(@_); }

  requires 'render';

  has _registry => (is=>'ro', required=>1, init_arg=>'registry');
  has parent => (is=>'ro', predicate=>'has_parent');
  has content => (is=>'ro', predicate=>'has_content');

  sub add_child {  }
  sub add_sibling { }


  sub get_component {
    my ($self, $comp_name, $args, $inner) = @_;
    $args->{parent} = $self;
    return $self->_registry->get_component($comp_name, $args, $inner);
  }

  sub render_component {
    my $self = shift;
    my $component = $self->get_component(@_);
    return $component->render;
  }

  around render => sub {
    my ($orig, $self) = (shift, shift);
    my @args = $self->prepare_render_args(@_);
    my @rendered = $self->$orig(@args);

    return $self->concat(@rendered);
  };

  sub prepare_render_args {
    my ($self, @args) = @_;
    my $content = $self->expand_content;
    return $content ? ( $content, @args) : @args;
  }

  sub expand_content {
    my $self = shift;
    return unless $self->has_content;
    return $self->concat($self->content->($self->content_args));
  }
  
  sub content_args {
    my $self = shift;
    return $self;
  }

  package Valiant::HTML::ComponentRegistry;

  use Moo;
  use Module::Runtime 'use_module';

  has factory_class => (is=>'ro', required=>1, default=>sub { 'Valiant::HTML::ComponentFactory' });
  has _components => (is=>'ro', required=>1, init_arg=>undef, default=>sub { +{} });

  sub new_factory {
    my ($self, %args) = @_;
    return use_module($self->factory_class)->new(%args);
  }

  sub add_component {
    my ($self, $comp_name, $factory_args) = @_;
    die "Component '$comp_name' already added" if exists $self->_components->{$comp_name};
    return $self->_components->{$comp_name} = $self->new_factory(%$factory_args, registry=>$self);
  }

  sub get_component {
    my ($self, $comp_name, $args, $inner) = @_;
    my $component_factory = $self->_components->{$comp_name} || die "Component '$comp_name' does not exist";
    my $component = $component_factory->create(%$args, (defined($inner) ? (content => $inner) : ()));
    return $component;
  }

  sub render_component {
    my $self = shift;
    my $component = $self->get_component(@_);
    return $component->render;
  }
  
  package Valiant::HTML::ComponentFactory;

  use Moo; 
  use Valiant::HTML::SafeString 'concat';

  has class => (is=>'ro', required=>1);
  has constructor => (is=>'ro', lazy=>1, required=>1, builder=>'_build_constructor' );
  has registry => (is=>'ro', required=>1);

  sub _build_constructor {
    return sub {
      my ($self, $class, %args) = @_;
      return $class->new(%args, registry=>$self->registry);
    };
  }

  has _init_args => (is=>'ro', init_args=>'init_args', predicate=>'has_init_args');

  sub get_init_args {
    my $self = shift;
    return $self->has_init_args ? %{$self->_init_args} : ();
  }

  sub prepare_args {
    my ($self, %args) = @_;
    %args = ($self->get_init_args, %args);
    return %args;
  }

  sub create {
    my $self = shift;
    my %args = $self->prepare_args(@_);
    my $component = $self->constructor->($self, $self->class, %args);
    return $component;
  }
}

{
  package Local::Template::Hello;

  use Moo;
  with 'Valiant::HTML::Component';

  has 'name' => (is=>'ro', required=>1);

  sub render {
    my ($self) = @_;
    return  $self->raw("<p>Hello ", $self->safe($self->name), "</p>");
  }

  package Local::Template::List;

  use Moo;
  with 'Valiant::HTML::Component';

  has 'items' => (is=>'ro', required=>1);

  sub render {
    my ($self) = @_;
    return  $self->raw(
              "<ol>",
                (map { 
                  $self->raw("<li>", $self->safe($_))
                } @{ $self->items }
                ),
              "</ol>");
  }

  package Local::Template::Page;

  use Moo;
  with 'Valiant::HTML::Component';

  has size => (is=>'ro', required=>1);

  sub render {
    my ($self) = @_;
    my $page = $self->get_component(Layout => +{title=>'Landing'}, sub {
      my $layout = shift;
      return  $layout->render_component(Hello => +{name=>'John'}),
              do {
                if($self->size ne 'big') {
                  $layout->render_component(List => +{items=>[1,2,3]});
                } else {
                  $layout->render_component(List => +{items=>[10,20,30]});
                }
              };
    });
    return $page->render;
  }


  package Local::Template::Layout;

  use Moo;
  with 'Valiant::HTML::Component';

  has 'title' => (is=>'ro', required=>1);

  sub render {
    my ($self, $inner) = @_;
    return  $self->raw('
      <html>
        <head>
          <title>', $self->safe($self->title), '</title>
        </head>
        <body>',
          $inner,
        '</body>
      </html>');
  }
}

ok my $registry = Valiant::HTML::ComponentRegistry->new;
ok $registry->add_component(Hello => +{class=>'Local::Template::Hello'});
ok $registry->add_component(List => +{class=>'Local::Template::List'});
ok $registry->add_component(Page => +{class=>'Local::Template::Page'});
ok $registry->add_component(Layout => +{class=>'Local::Template::Layout'});

ok my $hello = $registry->get_component(Hello => +{name=>'John'});
is $hello->render, '<p>Hello John</p>';

use Devel::Dwarn;

ok my $page = $registry->get_component(Page => {size=>'big'});
ok my $html = $page->render;  $html =~s/^\s+|\n//gm;
is $html, '<html><head><title>Landing</title></head><body><p>Hello John</p><ol><li>10<li>20<li>30</ol></body></html>';

warn $html;

done_testing;

__END__

  sub render($self) {
    my $list = $self->size ne 'big' ?
      <List items=[1,2,3] /> : 
      <List items=[10,20,30] />;

    return <Layout title='Landing'>
      <Hello name='John' />
      {{$list}}
      </Layout>
  }

  sub render {
    my ($self, $inner) = @_;
    return html {
      head {
        title { $self->title }
      }
      body { $inner }
    };
  }


  % layout 'layout.ep', title => 'Sign In';

%== form_for $person => +{ method=>'POST', style=>'width:20em; margin:auto'  }, begin
  % my $fb = shift;
  <fieldset>
    <legend>
      Sign In
    </legend>
    <div class='form-group'>
      %== $fb->model_errors(+{class=>'alert alert-danger', role=>'alert'});
    </div>
    <div class='form-group'>
      %== $fb->label('username');
      %== $fb->input('username', {class=>'form-control' });
    </div>
    <div class='form-group'>
      %== $fb->label('password');
      %== $fb->input('password', {class=>'form-control' });
    </div>
    %== $fb->submit('Sign In', +{class=>'btn btn-lg btn-primary btn-block'})
  </fieldset>
  <div class='text-center'><a href="/register">Register</a></div>
% end


sub render($self) {
  return _c Layout => +{ title=>'Sign In' }, sub($layout) {
    return  _c Form => +{ model=>$self->person, method=>'POST' }, sub($form) {
      return
        _r q[
          <fieldset>
            <legend>
              Sign In
            </legend>
            <div class='form-group'>],
        $form->model_errors(+{class=>'alert alert-danger', role=>'alert'}),
        _r q[
            </div>
            <div class='form-group'>],
        $form->label('username'),
        $form->input('username', {class=>'form-control' }),
        _r q[
            </div>
            <div class='form-group'>],
        $form->label('password'),
        $form->input('password', {class=>'form-control' }),
        $form->raw(q[</div>]),
        $form->submit('Sign In', +{class=>'btn btn-lg btn-primary btn-block'}),
        _r q[
          </fieldset>
          <div class='text-center'><a href="/register">Register</a></div>];
    },
  };
}

  return _c Layout => +{ title=>'Sign In' }, sub($layout) {
    return  _c Form => +{ model=>$self->person, method=>'POST' }, sub($form) {
      return
        _r q[
          <fieldset>
            <legend>
              Sign In
            </legend>
            <div class='form-group'>],
        $form->model_errors(+{class=>'alert alert-danger', role=>'alert'}),
        _r q[
            </div>
            <div class='form-group'>],
        $form->label('username'),
        $form->input('username', {class=>'form-control' }),
        _r q[
            </div>
            <div class='form-group'>],
        $form->label('password'),
        $form->input('password', {class=>'form-control' }),
        $form->raw(q[</div>]),
        $form->submit('Sign In', +{class=>'btn btn-lg btn-primary btn-block'}),
        _r q[
          </fieldset>
          <div class='text-center'><a href="/register">Register</a></div>];
    },
  };

  %= _c Layout => +{ title=>'Sign In' }, sub($layout) {
    %= _c Form => +{ model=>$self->person, method=>'POST' }, sub($form) {
      <fieldset>
        <legend>
          Sign In
        </legend>
        <div class='form-group'>
          %= $form->model_errors(+{class=>'alert alert-danger', role=>'alert'});
        </div>
        <div class='form-group'>
          %= $form->label('username');
          %= $form->input('username', {class=>'form-control' });
        </div>
        <div class='form-group'>
          %= $form->label('password'),
          %= $form->input('password', {class=>'form-control' }),
        </div>
        %= $form->submit('Sign In', +{class=>'btn btn-lg btn-primary btn-block'}),
      </fieldset>
      <div class='text-center'>
        <a href="/register">Register</a>
      </div>
    % },
  % };


sub render($self) {
  return _c Layout => +{ title=>'Sign In' }, sub($layout) {
    return  _c Form => +{ model=>$self->person, method=>'POST' }, sub($form) {



  <div class='form-group'>
    %= $form->model_errors(+{class=>'alert alert-danger', role=>'alert'});
  </div>;

  raw(q[<div class='form-group'>]),
  safe(do { $form->model_errors(+{class=>'alert alert-danger', role=>'alert'}); }),
  raw(q[</div>]),;

sub render($self) {
  <Layout title='Sign In'>
    <Form model="<%= $self->person %>" method='POST'>
      % my $form = shift;
      return
        <fieldset>
          <legend>
            Sign In
          </legend>
          <div class='form-group'>
            %= $form->model_errors(+{class=>'alert alert-danger', role=>'alert'});
          </div>
        </fieldset>
        ;
    </Form>
  </Layout>
}



sub {
    package Mojo::Template::Sandbox;
    BEGIN {${^WARNING_BITS} = "\x55\x55\x55\x55\x55\x55\x55\x51\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55"}
    use strict;
    use feature 'current_sub', 'evalbytes', 'fc', 'say', 'state', 'switch', 'unicode_strings', 'unicode_eval';
    my $_O = '';
    {
        {
            $a = 99;
            $_O .= "<div>\n";
            my $now = Mojo::Template::Sandbox::localtime();
            $_O .= '  Time: ';
            $_O .= scalar($now->hms);
            $_O .= "\n";
            if ($a == 100) {
                $_O .= "  ddddddd\n";
            }
            $_O .= "</div>\n";
        }
    }
    $_O;
}




sub render {
  my ($self, $content) = @_
  return 
    <html>
      <head>
        <title>{ $self->title }</title>
      </head>
      <body>
        { $content }
      </body>
    </html>;
}

sub name {
  return <p>{{ $self->first_name }} {{ $self->last_name }}</p>
}

sub render {
  return
    <html>{{
      Registry->create(Master => +{title=>$self->title}, sub {
        <p>Hello {{ $self->name }}</p>
      })
    }}</html>;

  return <Master 
          title="{ $self->title }">
    <p>Hello <name /></p>
    </Master>
}

