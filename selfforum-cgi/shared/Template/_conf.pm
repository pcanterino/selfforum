# Template/_conf.pm

# ====================================================
# Autor: n.d.p. / 2001-02-20
# lm   : n.d.p. / 2001-02-20
# ====================================================
# Funktion:
#      Bereitstellung der Ausgabeparameter
#      durch Kombination von User und Adminkonf.
# ====================================================

use strict;

package Template::_conf;

# ====================================================
# Funktionsexport
# ====================================================

use base qw(Exporter);
@Template::_conf::EXPORT = qw(get_view_params);

################################
# sub get_view_params
#
# Ausgabeparameter bestimmen
################################

sub get_view_params ($) {
  my $param = shift;
  my $default = $param -> {adminDefault};
  my %hash;

  %hash = (quoteChars    => $default -> {View} -> {quoteChars},
           sortedMsg     =>  $default -> {View} -> {sortMessages},
           sortedThreads => $default -> {View} -> {sortThreads}
          );

  \%hash;
}

# ====================================================
# Modulinitialisierung
# ====================================================

# making require happy
1;

# ====================================================
# end of Template::_conf
# ====================================================