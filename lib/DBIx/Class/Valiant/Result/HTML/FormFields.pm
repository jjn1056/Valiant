package DBIx::Class::Valiant::Result::HTML::FormFields;

use base 'DBIx::Class';

use warnings;
use strict;

__PACKAGE__->mk_classdata( __select_options_rs_for => {} );
__PACKAGE__->mk_classdata( __checkbox_rs_for => {} );
__PACKAGE__->mk_classdata( __radio_button_rs_for => {} );
__PACKAGE__->mk_classdata( __radio_buttons_for => {} );


__PACKAGE__->mk_classdata( __tags_by_column => {} );
__PACKAGE__->mk_classdata( __columns_by_tag => {} );

sub register_column {
    my ($self, $column, $info, @rest) = @_;
    $self->next::method($column, $info, @rest);

    my $tag_info = exists $info->{tag}
      ? $info->{tag}
      : exists $info->{tags}
        ? $info->{tags}
        : undef;

    return unless $tag_info;

    my @tags = (ref($tag_info)||'') eq 'ARRAY'
      ? @{$tag_info}
      : ($tag_info);

    $self->__tags_by_column->{$column} = \@tags;
    
    foreach my $tag (@tags) {
      push @{$self->__columns_by_tag->{$tag}}, $column;
    }
}

sub tags_by_column {
  my ($self, $column) = @_;
  return @{$self->__tags_by_column->{$column}||[]};
}

sub columns_by_tag {
  my ($self, $tag) = @_;
  return @{$self->__columns_by_tag->{$tag}||[]};
}

sub add_select_options_rs_for {
  my ($class, $column, $code) = @_;
  $class->__select_options_rs_for->{$column} = $code;
}

sub select_options_rs_for {
  my ($self, $column, %options) = @_;
  my $code = $self->__select_options_rs_for->{$column};
  my $rs = $code->($self, %options);
  my ($value_method, $label_method) = sub {
    my $class = shift->result_source->result_class;
    my ($value_method) = $class->columns_by_tag('option_value');
    my ($label_method) = $class->columns_by_tag('option_label');
    return ($value_method, $label_method);
  }->($rs);

  return $rs, $label_method, $value_method;
}

sub select_options_for {
  my ($self, $column, %options) = @_;
  my ($rs, $label_method, $value_method) = $self->select_options_rs_for($column, %options);
  my @options = map {[ $_->$label_method, $_->$value_method ]} $rs->all;
  return \@options;
}

sub add_checkbox_rs_for {
  my ($class, $column, $code) = @_;
  $class->__checkbox_rs_for->{$column} = $code;
}

sub checkbox_rs_for {
  my ($self, $column, %options) = @_;
  my $code = $self->__checkbox_rs_for->{$column};
  my $rs = $code->($self, %options);
  my ($value_method, $label_method) = sub {
    my $class = shift->result_source->result_class;
    my ($value_method) = $class->columns_by_tag('checkbox_value');
    my ($label_method) = $class->columns_by_tag('checkbox_label');
    return ($value_method, $label_method);
  }->($rs);

  return $rs, $label_method, $value_method;
}

sub checkbox_for {
  my ($self, $column, %options) = @_;
  my ($rs, $label_method, $value_method) = $self->checkbox_rs_for($column, %options);
  my @options = map {[ $_->$label_method, $_->$value_method ]} $rs->all;
  return \@options;
}

sub add_radio_button_rs_for {
  my ($class, $column, $code) = @_;
  $class->__radio_button_rs_for->{$column} = $code;
}

sub radio_button_rs_for {
  my ($self, $column, %options) = @_;
  my $code = $self->__radio_button_rs_for->{$column};
  my $rs = $code->($self, %options);
  my ($value_method, $label_method) = sub {
    my $class = shift->result_source->result_class;
    my ($value_method) = $class->columns_by_tag('radio_value');
    my ($label_method) = $class->columns_by_tag('radio_label');
    return ($value_method, $label_method);
  }->($rs);

  return $rs, $label_method, $value_method;
}

sub add_radio_buttons_for {
  my ($class, $column, $code) = @_;
  $class->__radio_buttons_for->{$column} = $code;
}
sub radio_buttons_for {
  my ($self, $column, %options) = @_;
  my $code = $self->__radio_buttons_for->{$column};
  my @buttons = $code->($self, %options);
  return @buttons;
}

1;

=head1 NAME

DBIx::Class::Valiant::Result::HTML::FormFields - DBIC Fields to HTML Form Fields

=head1 SYNOPSIS

    package Example::Schema::Result::Person;

    use base 'DBIx::Class::Core';

    __PACKAGE__->load_components('Valiant::Result::HTML::FormFields');

Or just add to your base Result class

    package Example::Schema::Result;

    use strict;
    use warnings;
    use base 'DBIx::Class::Core';

    __PACKAGE__->load_components('Valiant::Result::HTML::FormFields');

=head1 DESCRIPTION

    TBD

=head1 AUTHOR
 
John Napiorkowski L<email:jjnapiork@cpan.org>
  
=head1 SEE ALSO
 
L<Valiant>, L<DBIx::Class>

=head1 COPYRIGHT & LICENSE
 
Copyright 2020, John Napiorkowski L<email:jjnapiork@cpan.org>
 
This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut


