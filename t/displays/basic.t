use Test::Most;

{
  package Local::Test::User;

  use Moo;
  use Valiant::Validations;
  use Valiant::Formbuilder;

  #display html_form => +{}; # requires validation methods  # has is_valid, @fields, has_field, ? id,name, ?? ctx, ? init_values ? field_prefix ->values, html_attrs
  # ->model

  has name => (is=>'ro');

  validates 'name',
    presence => 1, 
    length => [2,24];

  form dataset => +{ class => 'Local::Test::User' }

  input 'name', +{
      required => 1, 
      size => 24, 
      placeholder => 'The User Name', 
      default_value => 'Joe Black',
      dataset => +{},
      # possible support:  hidden, id, readonly, disabled, maxlength, minlength, pattern, 
      # name:derived but overridable
    };
}

{
  ok my $object = Local::Test::User->new(name=>'Li');

}

done_testing;

__END__

  

  warn $object->get_attribute_value_for_display('name');
  warn $object->get_attribute_errors_for_display('name');

  $object->input_for('name')->..

  $object->error_messages_for('name')
  $object->has_errors_for('name')

  $object->display('html_form')
    ->attribute_validity_for('name')
    ->attribute('name')
      ->isvalid

