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

use vars qw(@ISA @EXPORT);

# ====================================================
# Funktionsexport
# ====================================================

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(get_view_params);

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