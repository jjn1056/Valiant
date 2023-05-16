package Example::View::JSON::Account::Edit;
 
use Moose;
 
extends 'Catalyst::View::BasePerRequest';
use JSON::MaybeXS;

has account => (is=>'ro', required=>1);

 
sub render {
  my ($self, $c) = @_;
  my $errors = $self->account->errors->as_json;
  my $response =  +{
    $self->account->get_columns,
    errors => $errors,
  };

  use Devel::Dwarn;
  Dwarn $response;

  return encode_json($response);
}
 
__PACKAGE__->config(
  content_type=>'application/json',
  status_codes=>[200,400]
);
 
__PACKAGE__->meta->make_immutable();