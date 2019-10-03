package Valiant;

use Moo;
use Valiant::Validators;

has 'validators' => (
  is => 'ro',
  required => 1,
);

1;

=head1 TITLE

Valiant - Validation Library

=head1 SYNOPSIS

  { 
      a => 'b',
      c => ['d','e'],
      f => {
        g => 'h',
        i => 'j',
      },
  }

    field "  "
    object { ...  }
    list [ ... ]

    # Option #1, dynamic

    my $validator = Valiant->new;

    my $compiled_check = $validator
      ->field(first_name => sub {
        my($field, $context) = @_;
        $field->required
          ->string(max=>12, min=>2, pattern=>qr/AZaz/)
          ->cb(sub {
              my $context = shift;
          });
      })
      ->object(sub {
        ->field('name')->add_constraint(...)
        ->field
        
      });


    my $result = $compiled_check->run($object, \%params);
        


    # Option, reflection

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

    my $compiled_checks = $validator->model(


    $c->view("JSON", $user);

    ## alternative reflectiojn...
    
    package Local::Validation::User;

    use Valiant::Factory +{
      class => 'Local::User',
      
    };


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

ValidateNewUser shoulld be different than ValidateUser



=head1 COPYRIGHT & LICENSE
 
Copyright 2019, John Napiorkowski L<email:jjnapiork@cpan.org>
 
This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

__END__

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


  $user->errors->{name}

validates
  field 'name' => ( 
    String => {min=>3, max=24},
    filters => ['trim', 'collapse_whitespace', 'normalize_whitespace']
  ),
  object '



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

  Valiant::MOP::Object->new(
    fields => [
      Valiant::MOP::Scalar->new

Valiant
  MOP
    Object
    Scalar
    Array
  Schema.pm
  ObjectType.pm
  ScalarType.pm
  Type.pm
  Type
    Code.pm
    String.pm
  Util.pm
  Exporter

Valiant
  Schema
  Type/Validator
  Utils
  Filter

package MyApp::Validation::Type;

use Moo;
use Valiant::ObjectType;

type 'Object';



  Validator
    Name
    Address

package Valiant::Validator::Name;

use Moo;

extends 'Valiant::Validator::String';

sub looks_like_a_name { ... }

around 'check', sub {
  my ($self, $orig, $value) = @_;
  return 0 unless $self->$orig($value);
  return 0 unless looks_like_a_name($value);
};

package Valiant::Validator::Address;

use Moo;

with 'Valiant::Validator';

has 



wild ideas for catalyst



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

