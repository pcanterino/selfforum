package Id;

################################################################################
#                                                                              #
# File:        shared/Id.pm                                                    #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>, 2001-05-03                          #
#                                                                              #
# Description: compose an unique ID (in CGI context)                           #
#                                                                              #
################################################################################

use strict;
use vars qw(
  @table
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
@EXPORT = qw(
  unique_id
  may_id
);

### sub unique_id () ###########################################################
#
# compose an unique ID
#
# Params: ~none~
#
# Return: Scalar: unique ID
#
sub unique_id () {
  my $id;

  my $ip=$ENV{REMOTE_ADDR};
  my $time=time;
  my $port=$ENV{REMOTE_PORT};
  my $rand=int(rand(time));

  # works only with IPv4! (will be changed later...)
  #
  $ip = hex(join ('',map {sprintf ('%02X',$_)} split (/\./,$ip)));

  join '' => map {to_base64 ($_)} ($time, $port, $ip, $rand, $$);
}

### sub to_base64 ($) ##########################################################
#
# only converts (max.) 32-bit numbers into a system with base 64
#
# Params: $x - number to convert
#
# Return: converted number ;-)
#
sub to_base64 ($) {
  my $x = shift;
  my $y = $table[$x % 64];

  $y = $table[$x % 64].$y while ($x = int ($x/64));

  $y;
}

BEGIN {
  # 64 'digits' (for our base 64 system)
  #
  @table = ('a'..'z','-','0'..'9','A'..'Z','_');

  # define sub may_id
  #
  *may_id = eval join quotemeta join ('' => @table) => (
    q[sub {local $_=shift; defined and length and not y/],
    q[//cd;}]
  );
}

# keep 'require' happy
1;

#
#
### end of Id ##################################################################