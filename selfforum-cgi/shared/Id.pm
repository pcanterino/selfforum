# Id.pm

##############################################
#                                            #
# Autor: n.d.p. / nd@o3media.de              #
#                                            #
# Letze Aenderung: n.d.p. / 2001-01-28       #
#                                            #
# ========================================== #
#                                            #
# Funktion:                                  #
#                                            #
# Bereitsstellen einer einmaligen ID         #
#                                            #
##############################################

use strict;

package Id;
require 5.000;

#####################
# Funktionsexport
#####################

require Exporter;
@Id::ISA = qw(Exporter);
@Id::EXPORT = qw(unique_id);

use vars qw(@table);

##########################################
# EXPORT                                 #
#                                        #
# sub &unique_id                         #
#                                        #
# Funktion:                              #
#      Rueckgabe der ID                  #
##########################################

sub unique_id {
  my $id;

  my $ip=$ENV{'REMOTE_ADDR'};
  my $time=time();
  my $port=$ENV{'REMOTE_PORT'};
  my $rand=int(rand(time()));
  $ip =  hex(join ('',map {sprintf ('%02X',$_)} split (/\./,$ip)));

  join '',map {to_base64 ($_)} (substr ($time,-9), $port, $ip, $rand, $$);
}

sub to_base64 ($) {
  my $x = shift;
  my $y = $table[$x % 64];

  while ($x = int ($x/64)) {$y = $table[$x % 64] . $y}

  # Rueckgabe
  $y;
}

BEGIN {
  srand(time()^$$);
  @table = ('a'..'z','-','0'..'9','A'..'Z','_');
}

# making 'require' happy
1;

#####################
# end of Id
#####################