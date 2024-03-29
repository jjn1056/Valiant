requires 'Moo' => '2.004004';
requires 'Class::Method::Modifiers';
requires 'Data::Localize' => '0.00028';
requires 'Data::Perl::Collection::Array';
requires 'DateTime::Format::Strptime';
requires 'DateTime';
requires 'FreezeThaw';
requires 'Lingua::EN::Inflexion', '0.002007';
requires 'Module::Runtime';
requires 'Role::Tiny::With';
requires 'Scalar::Util' => '1.55';
requires 'String::CamelCase';
requires 'File::Spec';
requires 'Text::Autoformat';
requires 'Carp';
requires 'Devel::StackTrace', '2.03';
requires 'Data::Dumper';
requires 'namespace::autoclean';
requires 'namespace::clean';
requires 'overload';
requires 'DBIx::Class';
requires 'Sub::Util';
requires 'HTML::Escape';
requires 'URI', '5.17';
requires 'Module::Pluggable::Object';
requires 'Class::Method::Modifiers';
requires 'Catalyst::View::BasePerRequest';
requires 'Sub::Util';
requires 'Attribute::Handlers';
requires 'JSON::MaybeXS';
requires 'URI::Escape';

on test => sub {
  requires 'Test::Most' => '0.34';
  requires 'Type::Tiny' => '1.012001';
  requires 'MooseX::NonMoose' => '0.26';
  requires 'MooseX::MarkAsMethods' => '0.15',
  requires 'DateTime::Format::Strptime';
  requires 'DateTime';
  requires 'Moo' => '2.004004';
  requires 'Test::Lib', '0.002';
  requires 'Test::Needs', '0.002006';
  requires 'DBIx::Class';
  requires 'DBIx::Class::Candy';
  requires 'Test::DBIx::Class'=> '0.52';
  requires 'HTML::Escape';
  requires 'Catalyst::Runtime';
};
