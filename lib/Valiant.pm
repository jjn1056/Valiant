package Valiant;

use Moo;
use Valiant::Validators;

has 'validators' => (
  is => 'ro',
  required => 1,
);

1;

#TODO lots of tests
#TODO DBIC integration
#TODO validate_associated
#TODO lots more prebuild validators
#TODO improve default localizations
#TODO add time/date/currency locations to i18n
#TODO make sure options are properly passed
#TODO Allow my $validations = Valiant::Class->new->validations()->validations()->validate(%params);i
#TODO maybe a helper for nested objects to allpoe by hashref (has attr => (is=>'ro', coerce_from_hash('MyApp::User'), ...)u'
#
#TODO what in the 'Validatable role' can move to Valient as a global?  thinkibg stuff for dependency
# injections and maybe internationalized?

=head1 TITLE


bind / create_or_update_for_validation (default is to just call new)
associated_for_validation   (default is call the accessor)
create_associated   (default is send the hash and assume there's a coercion or similar)

Date
  format 
  past
  future
  today
  min-date
  max-date
  12hourtime
  24hourtime

Object
  Some sort of shortcuts for common objects such as DateTime

Valiant - Validation Library

=head1 SYNOPSIS

  { 

    package Local::DomainUser;

    use Moose;

    has 'first_name' => (is=>'ro', required=>1);
    has 'last_name' => (is=>'ro', required=>1);
    has 'age' => (is=>'ro', required=>1);

    # JSON Support
    sub XXXX { # JSON to field map }

    sub field_mappings {
      my ($class, $field_mapping) = @_;
      $field_mapping->add(last => last_name, ...)
    }

    sub validate_model {

    }

    sub bind_model {
      $self, $form = @_
    }

=head1 AUTHOR
 
John Napiorkowski L<email:jjnapiork@cpan.org>
  
=head1 SEE ALSO
 
Half of CPAN :)

Valiant needs to wrap a model so you have a way to
catch errors during create and update, and also
Valient could introspect the model for how to work

MyApp::Validate::Base

export_ok qw(first last age);
export_ok ALL;
export_tags ( Common => [qw(first last age) ];


MyApp::Validate
MyApp::Validate::TypeLibrary; # these are automatically available everywhere
MyApp::Validate::User
MyApp::Validate::Validator::MyCustom
MyApp::Validate::Reflector::Mojolicious ;)
MyApp::Validate::IncludeProvider::OpenAPI :)

Valiant::Serializer::OpenAPI ...?

include 'Base' qw(:common first last age);

for 'MyApp::Schema::Resultset::User';  #can be set in MyApp::Validate
for $role or $type or $class
reflect last as { isa=>Str, require_with => 'first', max_length =>25, field_name=>'last_name'  },
  first as { isa=>Str, require_with => 'first', max_length =>25, field_name=>'first_name' },
  age as age # if you reflect a field that is already defined, we automatically do thi

# use the GraphQL trick you learned to export the default types

MyApp::Validate;

default_contraints Type::Standard


my $validator =$c->model('Validator::User')
  ->for($c->model('Schema::User')->new_result({}))
  ->fields($c->req->body_data)
  ->on_valid(sub {
      my ($model, $results) = @_;
    })
  ->on_error(sub {
      my ($model, $results, $c) = @_;
    }, $c);

my $result = $validator->run;

=head1 COPYRIGHT & LICENSE
 
Copyright 2020, John Napiorkowski L<email:jjnapiork@cpan.org>
 
This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

__END__

<form method='post'>
  <!-- Basic Info -->
  <label>
    First Name: <input type='text' name='first_name' />
  </label>
  <label>
    Last Name:<input type='text' name='last_name' />
  </label>

  <!-- Simple Nested -->
  <fieldset>
    <legend>Address</legend>
    <label>
      Street: <input type='text' name='address.street' />
    </label>
    <label>
      City: <input type='text' name='address.city' />
    </label>
    <label>
      State: <select name='address.state'>
        <option>NY
        <option>TX
        <option>CA
      </select>
    <label>
      Zip: <input type='text' name='address.zip' />
    </label>
  </fieldset>

  <!-- Simple Array -->
  <fieldset>
    <legend>Email Addresses</legend>
    <label>
      <input type='text' name='email[]' />
    </label>
  </fieldset>

  <!-- Complex Array -->
  <fieldset>
    <legend>Credit Cards</legend>
    <label>
      Number:<input type='text' name='creditcard[].number' />
    </label>
    <label>
      Expiration:<input type='text' name='creditcard[].expiration' />
    </label>
  </fieldset>

</form>


validates 'name',
 openapi => s

my $result = $user_object->validate({...});

$result ->is_valid
        ->is_invalid
        ->errors
          ->tree
          ->visit
          ->messages
          ->count
          ->fields
            ->messages

$result->errors->field('name')->messages  (num_messages, has_messages, clear_messages)
$result->errors->field('name')->add_error
$result->errors->field('name')->validators->{String}
$result->errors->{name}->messages
$result->errors->field('address')->field('city')->messages
$result->errors->{name}->value


  name => ( String->min(3)->max(3) ),
  addresses => ( Address->array->of(
    Object->field( street => String->min(4)->max(60) )
      ->field( city => String )


  field name => (
    String(min=>3, max=>30),
  ),
  field addresses => (
    
      Object(
        fields => [
          street => String(min=2,max=100),
        ]
      )
    )
  );


  field addresses => (
    Array(of => Address ...)
  );

  Object(
    fields => [
      name => String(min=>3, max=>30),
      name => All(Min(3),Max(24))
      address => Array(
        Object(
          fields => [
            street => String(min=2,max=100),
            city => String(min=2,max=100),
          ]
        )
      )
    ]
  );


MyApp->config(
  open_api => {
    inject_dependencies => {
      'Model::World' => 'World',
  }
)

sub :ApiDoc(
   parameters: [
      {
        in: 'query',
        name: 'worldName',
        required: true,
        type: 'string'
      }
    ],
    responses: {
      200: {
        description: 'A list of worlds that match the requested name.',
        schema: {
          type: 'array',
          items: {
            $ref: '#/definitions/World'
          }
        }
      },
      default: {
        description: 'An error occurred',
        schema: {
          additionalProperties: true
        }
      }
    }
  ) worlds($self, $ctx, $world) {


}

