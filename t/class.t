use Test::Most;

{

}




done_testing;

__END__

{
  ok my $object = Local::Test::Numericality->new(age=>11);
  ok !$object->validate(context=>['centarion', 'voter']);
  is_deeply +{ $object->errors->to_hash(full_messages=>1) },
    {
      age => [
        "Age must be greater than or equal to 18",
        "Age must be greater than or equal to 100",
      ],
    };
}

