package Example::Model::RegistrationForm;

{
  package Example::FormBuilder::InputAdaptor;

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

  package Example::FormBuilder::PasswordAdaptor;

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

  package Example::Model::RegistrationForm::FormBuilderAdaptor;

  use Moo;
  
  has _fb => (is=>'ro', init_arg=>'fb', required=>1);

  sub _input_adaptor {
    my ($self, $attr_name, $cb) = @_;
    my $fb = Example::FormBuilder::InputAdaptor->new(attribute_name=>$attr_name, fb=>$self->_fb);
    return $cb->($fb);
  }

  sub _password_adaptor {
    my ($self, $attr_name, $cb) = @_;
    my $fb = Example::FormBuilder::PasswordAdaptor->new(attribute_name=>$attr_name, fb=>$self->_fb);
    return $cb->($fb);
  }

  sub username { shift->_input_adaptor('username', @_) }
  sub first_name { shift->_input_adaptor('first_name', @_) }
  sub last_name { shift->_input_adaptor('last_name', @_) }
  sub password { shift->_password_adaptor('password', @_) }
  sub password_confirmation { shift->_password_adaptor('password_confirmation', @_) }

}

use Moose;
use Example::Syntax;
use Valiant::HTML::Form 'form_for';

extends 'Catalyst::Model';
with 'Catalyst::Component::InstancePerContext';

has ctx => (is=>'ro');
has model => (is=>'ro');

sub build_per_context_instance($self, $c, %args) {
  return ref($self)->new(ctx=>$c, %args);  
}

sub form($self, @args) {
  my $options = ((ref($args[0])||'') eq 'HASH') ? shift(@args) : +{};
  my $cb = shift(@args);

  return form_for $self->model, +{ 
    action => $self->ctx->req->uri, 
    csrf_token => $self->ctx->csrf_token,
    %$options, 
  }, sub($fb) {
      return $cb->( Example::Model::RegistrationForm::FormBuilderAdaptor->new(fb=>$fb), $fb)
  };

}

__PACKAGE__->meta->make_immutable();
