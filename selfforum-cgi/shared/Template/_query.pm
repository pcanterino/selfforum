package Template::_query;

################################################################################
#                                                                              #
# File:        shared/Template/_query.pm                                       #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>                                      #
#                                                                              #
# Description: compose a query string                                          #
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
@EXPORT = qw(query_string);

### url_encode () ##############################################################
#
# urlsafe encoding
# (more or less from CGI.pm)
#
# Params: $string - string to encode
#
# Return: encoded string
#
sub url_encode ($) {
  my $string = shift;
  $string=~s/([^a-zA-Z\d_.-])/uc sprintf('%%%02x' => ord($1))/eg;

  $string;
}

### query_string () ############################################################
#
# compose a query string
#
# Params: $parlist - hashref
#
# Return: scalar: query string
#
sub query_string ($) {
  my $parlist=shift;

  my $string = '?'.join ('&amp;' =>
    map {
      (ref)
      ? map{url_encode ($_).'='.url_encode ($parlist -> {$_})} @{$parlist -> {$_}}
      : url_encode ($_).'='.url_encode ($parlist -> {$_})
    } keys %$parlist
  );

  # return
  $string;
}

# keep 'require' happy
1;

#
#
### end of Template::_query ####################################################