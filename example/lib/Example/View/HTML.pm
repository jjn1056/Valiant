package Example::View::HTML;

use Moose;
use Mojo::ByteStream qw(b);
use Scalar::Util 'blessed';

extends 'Catalyst::View::MojoTemplate';

__PACKAGE__->config(
  helpers => {
    form_for => \&form_for,
    fields_for => \&fields_for,
    tag => \&tag,
    tag_options => \&tag_options,
    text_field_tag => \&text_field_tag,
  },
);

sub _parse_proto {
  my @proto = @_;
  my $content = (ref($proto[-1])||'') eq 'CODE' ? pop @proto : sub { undef };
  my %attrs = @proto;
  return ($content, %attrs);
}

sub _stringify_attrs {
  my %attrs = @_;
  my $attrs =  join ' ', map { "$_='$attrs{$_}'"} keys %attrs;
  return $attrs;
}

sub form_for {
  my ($self, $c, $model, @proto) = @_;
  my ($content, %attrs) = _parse_proto(@proto);

  if($model->can('in_storage') && $model->in_storage) {
    my $value = $model->model_name->param_key . '_edit';
    $attrs{id} ||= $value;
    $attrs{class} ||= $value;
  } else {
    my $value = $model->model_name->param_key . '_new';
    $attrs{id} ||= $value;
    $attrs{class} ||= $value;
  }
  $attrs{method} ||= 'POST';

  return $self->form_tag($c, '', %attrs, $content);
}

sub form_tag {
  my ($self, $c, $url, @proto) = @_;
  my ($content, %attrs) = _parse_proto(@proto);
  
  # $attr{action} ||= $c->uri_for()...

  my $out = $self->tag($c, 'form', \%attrs);
  if($content) {
    $out .= $content->();
    $out .= "</form>";
    $out = b $out;
  }

  return $out;
}

sub fields_for {
  my ($self, $c, $model, @proto) = @_;
  my ($content, %attrs) = _parse_proto(@proto);

  local $c->stash->{'valiant.view.form.model'} = $model;
  local $c->stash->{'valiant.view.form.namespace'}[0] = $model->model_name->param_key;

  $attrs{id} ||= $model->model_name->param_key;
  $attrs{method} ||= 'POST';

  my $attrs = _stringify_attrs(%attrs);



}

sub tag {
  my ($self, $c, $name, $options, $open) = @_;
  return b "<${name} @{[ _stringify_attrs(%{$options||+{}}) ]} @{[ $open ? '>':'/>' ]}";
}




sub text_field_tag {
  my ($self, $c, $name, $value, $options) = @_;
  $options ||= +{};
  $options->{type} ||= 'text';
  $options->{name} ||= $name;
  $options->{id} ||= do { $name=~tr/\./_/; $name };
  $options->{value} ||= $value;
  return $self->tag($c, 'input', $options);
}

1;
