package Time::German;

################################################################################
#                                                                              #
# File:        shared/Time/German.pm                                           #
#                                                                              #
# Authors:     Andr� Malo <nd@o3media.de>                                      #
#                                                                              #
# Description: determine time offset German Time <=> GMT (seconds)             #
#                                                                              #
################################################################################

use strict;
use vars qw(
  @EXPORT_OK
  %EXPORT_TAGS
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
use base 'Exporter';
@EXPORT_OK   = qw(localtime);
%EXPORT_TAGS = (overwrite_internal_localtime => 'localtime'); # ;-)) Thanks to Calocybe

################################################################################
#
# german summertime 1980-1995 (ydays)
#
my %summertime = (
  80 => [96, 271],
  81 => [87, 269],
  82 => [86, 268],
  83 => [85, 267],
  84 => [84, 273],
  85 => [89, 271],
  86 => [88, 270],
  87 => [87, 269],
  88 => [86, 268],
  89 => [84, 266],
  90 => [83, 272],
  91 => [89, 271],
  92 => [88, 270],
  93 => [86, 268],
  94 => [85, 267],
  95 => [84, 266]
);

### localtime () ###############################################################
#
# like 'localtime', but system independent
#
# Params: $time - time since epoch (GMT)
#
# Return: same as localtime, but german time ;-)
#
sub localtime (;$) {
  my $time = shift;
  $time = time unless defined $time;

  my ($hour,$mday,$mon,$year,$wday,$yday) = (gmtime($time))[qw(2 3 4 5 6 7)];
  my $offset = 1;

  # 1980 - 1995
  #
  if ($summertime{$year}) {
    $offset++ if (
      (
        $yday >  $summertime{$year} -> [0]  and
        $yday <  $summertime{$year} -> [1]
      ) or
      (
        $yday == $summertime{$year} -> [0]  and
        $hour >= 1
      ) or
      (
        $yday == $summertime{$year} -> [1]  and
        $hour <= 1
      )
    );
  }

  # > 1995
  #
  elsif ($year > 95) {
    # determine last Sunday in March or October
    #
    my $limit = $mday + int((31-$mday)/7) * 7 - $wday if ($mon == 2 or $mon == 9);

    $offset++ if (
      (
        $mon > 2          and
        $mon < 9
      ) or
      (
        $mon  == 2        and
        (
          $mday >  $limit  or
          $mday == $limit and
          $hour >= 1
        )
      ) or
      (
        $mon == 9         and
        (
          $mday <  $limit  or
          $mday == $limit and
          $hour <= 1
        )
      )
    );
  }

  return gmtime($time + $offset * 3600);
}

# keep 'require' happy
1;

#
#
### end of Time::German ########################################################