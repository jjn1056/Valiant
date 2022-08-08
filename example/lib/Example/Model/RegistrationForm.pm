package Example::Model::RegistrationForm;

{
  package Valiant::HTML::FormBuilderAdaptor::Input;

  use Moo;

  has _fb => (is=>'ro', init_arg=>'fb', required=>1);
  has attribute_name => (is=>'ro', required=>1);

  sub label {
    my ($self, @args) = @_;
    $self->_fb->label($self->attribute_name, @args);
  }
  sub input {
    my ($self, @args) = @_;
    $self->_fb->input($self->attribute_name, @args);
  }
  sub errors_for {
    my ($self, @args) = @_;
    $self->_fb->errors_for($self->attribute_name, @args);
  }

  package Valiant::HTML::FormBuilderAdaptor::Password;

  use Moo;

  has _fb => (is=>'ro', init_arg=>'fb', required=>1);
  has attribute_name => (is=>'ro', required=>1);

  sub label {
    my ($self, @args) = @_;
    $self->_fb->label($self->attribute_name, @args);
  }
  sub password {
    my ($self, @args) = @_;
    $self->_fb->password($self->attribute_name, @args);
  }
  sub errors_for {
    my ($self, @args) = @_;
    $self->_fb->errors_for($self->attribute_name, @args);
  }

  package Valiant::HTML::FormBuilderAdaptor;

  use Moo;
  
  has _fb => (is=>'ro', init_arg=>'fb', required=>1);

  sub _input_adaptor {
    my ($self, $attr_name, $cb) = @_;
    my $fb = Valiant::HTML::FormBuilderAdaptor::Input->new(attribute_name=>$attr_name, fb=>$self->_fb);
    return $cb->($fb);
  }

  sub _password_adaptor {
    my ($self, $attr_name, $cb) = @_;
    my $fb = Valiant::HTML::FormBuilderAdaptor::Password->new(attribute_name=>$attr_name, fb=>$self->_fb);
    return $cb->($fb);
  }
}

use Moose;
use Example::Syntax;
use Valiant::HTML::Form 'form_for';

extends 'Catalyst::Model';

sub fields {
  return
    username => {type=>'input'},
    first_name => {type=>'input'},
    last_name => {type=>'input'},
    password => {type=>'password'},
    password_confirmation => {type=>'password'},
}

has ctx => (is=>'ro');
has model => (is=>'ro');
has adaptor_class => (is=>'ro');

sub COMPONENT {
  my ($class, $app, $args) = @_;
  $args = $class->merge_config_hashes($class->config, $args);
  my $adaptor_class = $class->build_adaptor($app, $args);
  $args->{adaptor_class} = $adaptor_class;
  return bless $args, $class;
}

sub build_adaptor {
  my ($class, $app, $args) = @_;
  my $adaptor_class = "${class}::_Adaptor";

  eval "
    package $adaptor_class;
    use Moo;
    extends 'Valiant::HTML::FormBuilderAdaptor';
  ";
  die $@ if $@;

  require Sub::Util;

  my %fields = $class->fields;
  foreach my $attr (keys %fields) {
    my $type = $fields{$attr}->{type};
    my $method = Sub::Util::set_subname "${adaptor_class}::${attr}" => sub {
      my $adaptor = "_${type}_adaptor";
      shift->$adaptor($attr, @_);
    };
    no strict 'refs';
    *{"${adaptor_class}::${attr}"} = $method;
  }

  return $adaptor_class;
}
 
## TODO handle if we are wrapping a model that already does ACCEPT_CONTEXT
sub ACCEPT_CONTEXT {
  my $self = shift;
  my $c = shift;
 
  my $class = ref($self);
  my %args = (%$self, class=>$class, ctx=>$c, @_);  

  return $class->new(%args);
}

sub form($self, @args) {
  my $options = ((ref($args[0])||'') eq 'HASH') ? shift(@args) : +{};
  my $cb = shift(@args);

  return form_for $self->model, +{ 
    action => $self->ctx->req->uri, 
    csrf_token => $self->ctx->csrf_token,
    %$options, 
  }, sub($fb) {
      return $cb->($self->adaptor_class->new(fb=>$fb), $fb),
  };

}

__PACKAGE__->meta->make_immutable();
