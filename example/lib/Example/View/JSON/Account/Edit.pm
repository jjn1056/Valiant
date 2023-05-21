package Example::View::JSON::Account::Edit;
 
use Moose;
use Example::Syntax;

extends 'Catalyst::View::JSONBuilder';

has account => (is=>'ro', required=>1);

sub has_attribute_for_json {
  my ($self, $model, $name) = @_;
  return 0;
}

sub render_json {
  my ($self, $c) = @_;
  use Devel::Dwarn;
  Dwarn [$self->account->errors->as_json(full_messages=>1)];

  my $jb = $self->json_builder('account'); # if value doesn't match a model or is empty , create empty model at this namespace

  return $jb->string('username', {value=>undef, omit_undef=>1})
    ->with_model($self->account->profile, sub ($v, $jb, $profile) {
      $jb->string('address', +{name=>'address-proxy'})
    })
    ->string('first_name', {name=>'first-name', value=>'1111'})
    ->string('empty', {value=>'abc', omit_empty=>1})
    ->string('tokena', {value=>"ssss", name=>'token-a'})
    ->string('token', "sdfsdfsdfsdfsdf")
    ->object('profile', +{namespace=>'me'}, sub($v, $jb, $profile) {
      $jb->string('address')
        ->if(1, sub($v, $jb) { $jb->string('city', $jb->current_model->address) })
        ->if(sub {0}, sub($v, $jb) { $jb->string('city', $jb->current_model->address) })  
        ->number('state_id') 
    })
    ->object('profile', +{namespace=>'empty-profile', omit_empty=>1}, sub($v, $jb, $profile) {})
    ->object('profile', +{namespace=>'empty-profile-ok'}, sub($v, $jb, $profile) {}) 
    ->object('profile', \&render_profile)
    ->string('last_name')
    ->array('person_roles', +{namespace=>'empty-pr', omit_empty=>1}, sub($v, $jb, $person_role) {})
    ->array('person_roles', sub($v, $jb, $person_role) {
      $jb->number('role_id');
    })
    ->array('credit_cards', +{namespace=>'credit-cards'}, sub($v, $jb, $credit_card) {
      $jb->number('id')
        ->string('_delete')
        ->string('card_number');
        #->date('expiration')
    });

    # ->model() set current model until end, if hashref make that into a model
}

sub render_profile($self, $jb, $profile) {
  return $jb->string('address')
    ->string('city')
    ->number('state_id', {name=>'state-id'})
    ->string('zip', {value=>undef})
    ->string('phone_number')
    ->string('birthday')
    ->string('status')
    ->boolean('registered')
    ->number('employment_id')
    ->object($self->account->profile, sub ($v, $jb, $p) {
      $jb->string('address')
        ->string('city')
    })
    ->object($self->account->profile, {namespace=>'pro1'}, sub ($v, $jb, $p) {
      $jb->string('address')
        ->string('city')
    }) 

}
 
__PACKAGE__->config(
  status_codes=>[200,400]
);
 
__PACKAGE__->meta->make_immutable();

__END__

  $jb->username_str
    ->first_name_str
    ->str::last_name
    ->profile(sub($jb, $profile) {
      $jb->address
        ->city
        ->state_id
        ->zip
        ->phone_number
        ->birthday
        ->status
        ->registered
        ->employment_id;
    })
    ->person_roles(sub($jb, $person_role) {
      $jb->role_id;
    })
    ->credit_cards(sub($jb, $credit_card) {
      $jb->id
        ->card_number
        ->expiration
        ->_delete;
    });
