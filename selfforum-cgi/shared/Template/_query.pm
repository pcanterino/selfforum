# Template/_query.pm

# ====================================================
# Autor: n.d.p. / 2000-12-30
# lm   : n.d.p. / 2001-02-04
# ====================================================
# Funktion:
#      Erzeugen eines Querystrings
# ====================================================

use strict;

package Template::_query;

# ====================================================
# Funktionsexport
# ====================================================

use base qw(Exporter);
@Template::_query::EXPORT = qw(query_string);

################################
# sub query_string
#
# Querystring erzeugen
################################

sub query_string ($) {
  my $parlist=shift;

  my $string = '?'.join ('&amp;',
                         map {(ref)?map{&url_encode ($_).'='.&url_encode ($parlist -> {$_})} @{$parlist -> {$_}}:
                                    &url_encode ($_).'='.&url_encode ($parlist -> {$_})}
                           keys %$parlist);

  # return
  $string;
}

# ====================================================
# Private Funktionen
# ====================================================

################################
# sub url_encode
#
# URL-Codierung
# (mehr oder weniger aus
#  CGI.pm geklaut...)
################################

sub url_encode ($) {
  my $string = shift;
  $string=~s/([^a-zA-Z\d_.-])/uc sprintf('%%%02x',ord($1))/eg;

  $string;
}

# ====================================================
# Modulinitialisierung
# ====================================================

# making require happy
1;

# ====================================================
# end of Template::_query
# ====================================================