package Template::Plugin::Valiant::Form;

use warnings;
use strict;
use base 'Template::Plugin';

sub new {
  my ($class, $context, $model, $args) = @_;
  return my $self = bless {
    model => $model,
    current_node => [],
    stream => [],
  }, $class;
}

sub _add_node {
  my ($self, $name, $attrs) = @_;
  push @{$self->{current_node}}, $name;
  $self->_add_tag($name,$attrs);
}

sub _add_tag {
  my ($self, $name, $attrs) = @_;
  push @{$self->{stream}}, [$name, $attrs];
}

sub _add_text {
  my ($self, $text) = @_;
  push @{$self->{stream}}, [undef, $text];

}

sub _add_end {
  my ($self) = shift;
  my $current_node = pop @{$self->{current_node}||[]};
  if($current_node) {
    push @{$self->{stream}}, ["/$current_node", +{}];
  } 
}

sub form {
  my ($self, $attrs) = @_;
  $self->_add_node('form', $attrs);
  return $self;

}

sub h1 {
  my ($self, $attrs) = @_;
  my $content = delete $attrs->{content};
  $self->_add_node('h1', $attrs);
  if($content) {
    $self->_add_text($content);
  }
  $self->_add_end;
  return $self;
}

sub p {
  my ($self, $attrs) = @_;
  my $content = delete $attrs->{content};
  $self->_add_node('p', $attrs);
  if($content) {
    $self->_add_text($content);
  }
  $self->_add_end;
  return $self;
}

sub text {
  my ($self, $text) = @_;
  $self->_add_text($text);
  return $self;
}

sub label {
  my ($self, $attrs) = @_;
  my $text = $attrs->{text} || $self->{model}->human_attribute_name($attrs->{for});
  $self->_add_node('label', $attrs);
  $self->_add_text($text);
  $self->_add_end;
  return $self;
}

sub input {
  my ($self, $attrs) = @_;
  $attrs->{type} ||= 'text';
  $attrs->{id} ||= $attrs->{name};
  $attrs->{placeholder} ||= $self->{model}->human_attribute_name($attrs->{name});

  if($self->{model}->errors->size) {
    $attrs->{class} .= ' is-invalid';
  }

  if(my $label = delete $attrs->{label}) {
    my %label_params = %$label if ref($label);
    $self->label({for=>$attrs->{name}, %label_params});
  }

  $self->_add_tag('input', $attrs);
  if($self->{model}->errors->size) {
    $self->_add_node('div', +{class=>'invalid-feedback'});
    $self->_add_text( [$self->{model}->errors->full_messages_for($attrs->{name})]->[0] );
    $self->_add_end;
  }

  return $self;
}

sub password {
  my ($self, $attrs) = @_;
  my $confirmation = delete $attrs->{confirmation} if exists $attrs->{confirmation};
  $self->input({ type=>'password', %$attrs});
  if($confirmation) {
    delete $attrs->{label} if exists $attrs->{label};
    return $self->input({ type=>'password', %$attrs, name=> $attrs->{name} .'_confirmation'});
  } else {
    return $self;
  }
}

sub button {
  my ($self, $attrs) = @_;
  my $content = delete $attrs->{content};
  $self->_add_node('button', $attrs);
  if($content) {
    $self->_add_text($content);
    $self->_add_end;
  }
  return $self;
}

sub model_errors {
  my ($self) = @_;
  if(my @errors = $self->{model}->errors->model_errors_array(1)) {
    my $error = join ', ', @errors;
    warn "eeeee $error";
    $self->_add_node('div',{class=>'is-invalid'} );
    $self->_add_text($error);
    $self->_add_end;
  }
  return $self;
}

sub submit {
  my ($self, $attrs) = @_;
  $self->button({type=>'submit', %$attrs});
}

sub end {
  my ($self) = @_;
  $self->_add_end;  
  if(@{$self->{current_node}}) {
    return $self;
  } else {
    return $self->to_html;
  }
}

sub to_html {
  my $self = shift;
  my $html = '';
  foreach my $element (@{$self->{stream}}) {
    if(my $tag = $element->[0]) {
      my %attrs = %{$element->[1]||+{}};
      $html .= "<$tag @{[ join ' ', map { qq[$_='$attrs{$_}'] } keys %attrs ]}>";
    } else {
      $html .= $element->[1];
    }
  }
  return $html;
}

1;
