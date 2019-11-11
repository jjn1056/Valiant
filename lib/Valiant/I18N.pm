package Valiant::I18N;

use Moo;
use File::Spec;
use Data::Localize;
use Data::Localize::MultiLevel;
use Scalar::Util;

our $dl;
our %locale_paths;

# add -namespace='namespace to use to find the locale dir'
sub import {
  my $class = shift;
  my $target = caller;
  $class->init;
  $class->add_locale_path(_locale_path_from_module($target));

  no strict 'refs';
  *{"${target}::_t"} = sub { $class->_t(@_) };
  #\&{"${class}::_t"};
}

sub dl { $dl };

sub init {
  my $class = shift;
  return if $dl;
  $dl = Data::Localize->new;
  $class->add_locale_path(_locale_path_from_module($class));
  return $dl;
}

sub add_locale_path {
  my ($class, $path) = @_;
  return if $locale_paths{$path};
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

sub translate { 
  my ($self, $key, %args) = @_;
  return $key unless $self->i18n_tag($key);

  # TODO handle scope, defaults, count and model
  my @keys = ($key, @{delete($args{default})||[]});
  foreach my $possible (@keys) {
    warn "trying $$possible";
    my $translated = $dl->localize($$possible, \%args);
    return $translated unless $translated eq $$possible;
  }
}

sub detect_languages_from_header {
  my ($class, $header) = @_;
  return $dl->detect_languages_from_header($header);
}

sub set_languages {
  my ($class, @languages) = @_;
  $dl->set_languages(@languages);
}

sub i18n_tag {
  my ($class, $tag) = @_;
  return (ref($tag)||'') eq 'Valiant::I18N::Tag' ? 1:0;
}

*_t = \&make_tag;
sub make_tag($) {
  my ($class, $tag) = @_;
  return bless \$tag, 'Valiant::I18N::Tag';
}

1;
