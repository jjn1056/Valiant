package Example::View::HTML::FormFor;

use Moose;
use Example::Syntax;
use Valiant::HTML::Form 'form_for';
 
extends 'Example::View::HTML';

has 'model' => (is=>'ro', required=>1);
has 'options' => (is=>'ro', required=>1);
has 'form_builder' => (is=>'rw', required=>0, predicate=>'has_form_builder', handles=>[qw/legend input errors_for model_errors/]);

## This is a good place to put any code that needs to wrap formbuilder methods with
## context / request related information and other methods that should be scoped
## to the form context in general.  Consider putting generic extensions to Formbuilder
## into Example::FormBuilder.

sub prepare_build_args($class, $c, $model, $options={}, @args) {
  return model => $model, options => $options, @args;
};

sub execute_code_callback($self, @args) {
  return form_for $self->model, +{ 
    action => $self->ctx->req->uri, 
    csrf_token => $self->ctx->csrf_token,
    builder => "@{[ $self->app ]}::FormBuilder",
    ##view => $self->root,
    %{$self->options}, 
  }, sub($ff, $model) {
    $self->form_builder($ff);
    return $self->code->($self, $ff, $model);
  };
}

sub render($self, $c, $content) {
  return $content;
}

1;
