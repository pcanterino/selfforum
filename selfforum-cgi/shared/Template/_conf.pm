package Template::_conf;

################################################################################
#                                                                              #
# File:        shared/Template/_conf.pm                                        #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>, 2001-06-16                          #
#                                                                              #
# Description: combine user and default config                                 #
#                                                                              #
################################################################################

use strict;
use vars qw(
  @EXPORT
  $VERSION
);

################################################################################
#
# Version check
#
$VERSION = do { my @r =(q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

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
