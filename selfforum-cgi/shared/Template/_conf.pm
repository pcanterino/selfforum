package Template::_conf;

################################################################################
#                                                                              #
# File:        shared/Template/_conf.pm                                        #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>                                      #
#                                                                              #
# Description: combine user and default config                                 #
#                                                                              #
################################################################################

use strict;
use vars qw(
  @EXPORT
);

################################################################################
#
# Version check
#
# last modified:
#    $Date$ (GMT)
# by $Author$
#
sub VERSION {(q$Revision$ =~ /([\d.]+)\s*$/)[0] or '0.0'}

################################################################################
#
# Export
#
use base qw(Exporter);
@EXPORT = qw(get_view_params);

### get_view_params () #########################################################
#
# determine output parameters
#
# Params: $param - hashref
#
# Return: hashref
#
sub get_view_params ($) {
  my $param = shift;
  my $default = $param -> {adminDefault};
  my %hash;

  %hash = (
    quoting       => $default -> {View} -> {quoting},
    quoteChars    => $default -> {View} -> {quoteChars},
    sortedMsg     => $default -> {View} -> {sortMessages},
    sortedThreads => $default -> {View} -> {sortThreads}
  );

  \%hash;
}

# keep 'require' happy
1;

#
#
### end of Template::_conf #####################################################