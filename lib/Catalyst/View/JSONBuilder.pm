package Catalyst::View::JSONBuilder;

use Moo;
use Carp;
use JSON::MaybeXS ();
use Module::Runtime 'use_module';

extends 'Catalyst::View::BasePerRequest';

our $MODEL_BUILDER = 'Catalyst::View::JSONBuilder::Model';

has 'model_builder' => (
  is=>'ro',
  required=>1,
  default=>sub { $MODEL_BUILDER },
);

has 'json_args' => (
  is=>'ro',
  required=>1,
  default=>sub { +{} },
);

has 'json' => (
  is=>'ro', 
  required=>1, 
  lazy=>1,
  default=>sub {
    my %args = %{ shift->json_args };
    return JSON::MaybeXS->new(%args, utf8=>1);
  },
  handles => {
    encode_json => 'encode',
  },
);

sub json_true { JSON::MaybeXS::true() } 
sub json_false { JSON::MaybeXS::false() }

sub get_model_for_json {
  my ($self, $name) = @_;
  return $self->to_model if $self->can('to_model');
  return $self->get_attribute_for_json($name) if $self->can('get_attribute_for_json');
  return $self->$name if $self->can($name);
  croak "Can't find model for $name";
}

sub json_builder {
  my ($self, $model) = @_;
  my $jb = use_module($self->model_builder)->new(
    view => $self,
    model => $model,
  );
  return $jb;
}

sub render {
  my ($self, $c, @args) = @_;
  my $jb = $self->render_json($c, @args);
  my $json = $self->encode_json(my $data = $jb->data);

  use Devel::Dwarn;
  Dwarn $json;
  Dwarn $data;

  return $json;
}

__PACKAGE__->config(content_type=>'application/json');

=head1 NAME

Catalyst::View::JSONBuilder - Per Request, JSON view that wraps a model

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

This class inherits all of the attributes from L<Catalyst::View::BasePerRequest>

=head1 METHODS

This class inherits all of the methods from L<Catalyst::View::BasePerRequest> as well as:

=head1 EXPORTS

=head1 SUBCLASSING

You can subclass this view in order to provide your own default behavior and additional methods.

=head1 SEE ALSO
 
L<Catalyst::View>, L<JSON::MaybeXS>, L<Catalyst::View::BasePerRequest>

=head1 AUTHOR
 
See L<Valiant>

=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut
