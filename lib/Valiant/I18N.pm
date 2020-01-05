package Valiant::I18N;

use Moo;
use File::Spec;
use Data::Localize;
use Data::Localize::MultiLevel;
use Scalar::Util;
use Carp;

our $dl;
our %locale_paths;

#TODO  add -namespace='namespace to use to find the locale dir'
sub import {
  my $class = shift;
  my $target = caller;
  $class->init;
  $class->add_locale_path(_locale_path_from_module($target)); #TODO Should we also look it parent directories?

  no strict 'refs';
  *{"${target}::_t"} = sub { $class->make_tag(@_) };
}

sub dl { $dl };

sub init {
  my $class = shift;
  return if $dl;
  $dl = Data::Localize->new;
  $class->add_locale_path(_locale_path_from_module($class)); #TODO do we need to load the $class @ISA as well?
  return $dl;
}

sub add_locale_path {
  my ($class, $path) = @_;
  return if $locale_paths{$path};
  # TODO need to skip if there's no locale directory
  warn "Adding locale_path at $path" if $ENV{VALIANT_DEBUG};
  $dl->add_localizer(Data::Localize::MultiLevel->new(paths => [$path]));
  $locale_paths{$path} = 1;
}

sub _module_path {
  my @parts = split '::', shift;
  my $path = File::Spec->catfile(@parts);
  return $INC{"${path}.pm"};
}

sub _locale_path_from_module {
  my $module_path = _module_path(shift);
  my ($vol, $dir, $file) = File::Spec->splitpath($module_path);
  my $locale_path = File::Spec->catfile($dir, 'locale','*.*');
  return $locale_path;
}

sub _lookup_translation_by_count {
  my ($self, $count, $translated, %args) = @_;
  $translated = $translated->{zero} if $count == 0 and $translated->{zero};
  $translated = $translated->{one} if $count == 1 and $translated->{one};
  $translated = $translated->{other} if $count > 1 and $translated->{other};

  die "Can't find a 'count' option for '$count'" if ref $translated; 

  # Ok, need to do any variable subsitutions again. Just stole this from
  # Data::Localize::Format::NamedArgs

  # TODO this has an error when $args{$1} is 0
  $translated =~ s/\{\{([^}]+)\}\}/ $args{$1} || '' /gex;

  return $translated;
}

sub translate { 
  my ($self, $key, %args) = @_;

  my @defaults = @{ delete($args{default})||[] };
  my $scope = delete($args{scope})||'';
  my $count = $args{count};

  # TODO work around 0 count bug in Data::Localize until I can get a fix in
  $args{count} = 'zero' if defined($count) && $count == 0;

  $scope = join('.',@{$scope}) if (ref($scope)||'') eq 'ARRAY';

  # TODO deal with $count

  # $key can be either a string or a tag.
  $key = $$key if $self->is_i18n_tag($key);
  $key = "${scope}.${key}" if $scope;
  my $translated = $dl->localize($key, \%args);

  # If $translated is a hashref that means we need to apply the $count
  $translated = $self->_lookup_translation_by_count($count, $translated, %args)
    if ref($translated) && defined($count);

  # Is this a bug in Data::Localize?  Seems like ->localize just returns
  # the $key if it fails to actually localize.  I would think it should
  # return undef;

  return $translated unless $translated eq $key;

  # Ok if we got here that means the $key failed to localize.  So we will 
  # iterate over $args{defaults}.  If a defaut is a tag we try to localize
  # it.  First tag to localize is returned.  If however we encounter a 
  # default that is not a tag we just return that without trying to localize
  # it.  So you should stick your ultimate fallback string at the very end
  # of the defaults list.

  foreach my $default(@defaults) {
    return $default unless $self->is_i18n_tag($default);
    my $tag = $$default;
    my $translated = $dl->localize($tag, \%args);

    $translated = $self->_lookup_translation_by_count($count, $translated, %args)
      if ref($translated) and defined($count);

    return $translated unless $translated eq $tag; # See note above
  }

  my $list = join (', ', $key, map { $$_ if $self->is_i18n_tag($_) } @defaults);
  Carp::croak "Can't find a translation in ($list)";
}

sub detect_languages_from_header {
  my ($class, $header) = @_;
  return $dl->detect_languages_from_header($header);
}

sub set_languages {
  my ($class, @languages) = @_;
  $dl->set_languages(@languages);
}

sub is_i18n_tag {
  my ($class, $tag) = @_;
  return (ref($tag)||'') eq 'Valiant::I18N::Tag' ? 1:0;
}

sub make_tag($) {
  my ($class, $tag) = @_;
  return bless \$tag, 'Valiant::I18N::Tag';
}

1;
