package Conf;

################################################################################
#                                                                              #
# File:        shared/Conf.pm                                                  #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>                                      #
#                                                                              #
# Description: read and parse configuration files                              #
#                                                                              #
################################################################################

use strict;
use vars qw(
  @EXPORT
);

use XML::DOM;

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
@EXPORT = qw(read_script_conf);

### add_limit () ###############################################################
#
# add limited data
#
# Params: $node   - element node
#         $conf   - hashref of config hash (will be modified)
#         $Script - scriptname (first name)
#
# Return: ~none~
#
sub add_limit ($$$) {
  my ($node, $conf, $Script) = @_;

  my %apps = map {($_ -> getFirstChild -> getData => 1)}
                   $node -> getElementsByTagName ('Application',0) -> item (0)
                   -> getElementsByTagName ('Script',0);

  if ($apps {$Script}) {
    foreach ($node -> getElementsByTagName ('Constant', 0)) {add_data ($_, $conf)}
    foreach ($node -> getElementsByTagName ('Property', 0)) {add_prop ($_, $conf)}}

  return;
}

### add_prop () ################################################################
#
# add a property (recursive if necessary)
#
# Params: $node - element node
#         $conf - hashref of config hash (will be modified)
#
# Return: ~none~
#
sub add_prop ($$) {
  my ($node, $conf) = @_;

  my $name = $node -> getAttribute ('name');

  die "element 'Property' requires attribute 'name' - aborted" unless (length ($name));

  my @props  = $node -> getElementsByTagName ('Property', 0);
  my @vars = $node -> getElementsByTagName ('Variable', 0);
  my @lists  = $node -> getElementsByTagName ('List', 0);

  # Properties
  #
  if (@props) {
    for (@props) {
      my $hash = (defined $conf -> {$name})?$conf -> {$name}:{};

      die "name '$name' is defined for 'Property' and 'Variable' - aborted" unless (ref $hash eq 'HASH');

      &add_prop ($_, $hash);
      $conf -> {$name} = $hash;}}

  # Array
  #
  if (@lists) {
    for (@lists) {
      my $lname = $_ -> getAttribute ('name');

      die "element 'List' requires attribute 'name' - aborted" unless (length ($lname) and defined ($lname));
      die "double defined name '$lname' - aborted" if ( exists ( $conf -> {$name} -> {$lname} ) );

      $conf -> {$name} -> {$lname} = [map {($_ -> hasChildNodes)?$_ -> getFirstChild -> getData:undef} $_ -> getElementsByTagName ('ListItem', 0)];}}

  # Hash
  #
  if (@vars) {
    for (@vars) {
      my $vname = $_ -> getAttribute ('name');

      die "element 'Variable' requires attribute 'name' - aborted" unless (length ($vname) and defined ($vname));
      die "double defined name '$vname' - aborted" if ( exists ( $conf -> {$name} -> {$vname} ) );

      $conf -> {$name} -> {$vname} = ($_ -> hasChildNodes)?$_ -> getFirstChild -> getData:undef;}}

  return;
}

### add_data () ################################################################
#
# add a real value (Constant or Variable)
#
# Params: $node - Element node
#         $conf - hashref of config hash (will be modified)
#
# Return: ~none~
#
sub add_data ($$) {
  my ($node, $conf) = @_;
  my $name = $node -> getAttribute ('name');

  die q"element '".$node -> getNodeName.q"' requires attribute 'name' - aborted" unless (length ($name) and defined ($name));
  die q"double defined name '$name' - aborted" if ( exists ( $conf -> {$name} ) );

  $conf -> {$name} = ($node -> hasChildNodes)?$node -> getFirstChild -> getData:undef;

  return;
}

### parse_script_conf () #######################################################
#
# parse a config file
#
# Params: $filename - filename
#         $conf     - hashref of config hash (hash will be modified)
#         $Script   - scriptname
#
# Return: ~none~
#
sub parse_script_conf ($\%$) {
  my ($filename, $conf, $Script) = @_;

  if (-f $filename) {
    my $xml = new XML::DOM::Parser -> parsefile ($filename);
    my $config = $xml -> getElementsByTagName ('Config', 0) -> item (0);

    add_data  $_, $conf          for ($config -> getElementsByTagName ('Constant', 0));
    add_prop  $_, $conf          for ($config -> getElementsByTagName ('Property', 0));
    add_limit $_, $conf, $Script for ($config -> getElementsByTagName ('Limit', 0));
  }

  return;
}

### read_script_conf () ########################################################
#
# read and parse whole script config.
#
# Params: $Config - /path/to/config-dir   # NO trailing slash please
#         $Shared - /path/to/shared-dir   #        -- " --
#         $Script - scriptname
#
sub read_script_conf ($$$) {
  my ($Config, $Shared, $Script) = @_;

  $Script =~ s/^(.*)\..*$/$1/;             # extract script's 'first name'
  my $common  = "$Shared/common.xml";      # shared config file
  my $group   = "$Config/common.xml";      # group config file
  my $special = "$Config/$Script.xml";     # special script config file
  my %conf=();                             # config hash

  parse_script_conf ($common , %conf, $Script);
  parse_script_conf ($group,   %conf, $Script);
  parse_script_conf ($special, %conf, $Script);

  # return
  #
  \%conf;
}

# keep 'require' happy
1;

#
#
### end of Conf ################################################################

### show() #####################################################################
#
# mini data dumper
#
# Usage: Conf::Test::show (hashref)
#
package Conf::Test;sub show{print"Content-type: text/plain\n\n";&hash($_[
0],'')}sub hash{my($ref,$string)=@_;foreach(sort keys%$ref){my$val=$ref->
{$_};unless(ref($val)){print$string,$_,' = ',$val,"\n";next;}else{if(ref(
$val)eq 'HASH'){&hash($val,"$string$_ -> ");}else{if(ref($val)eq'ARRAY'){
&array($val,"$string$_ -> ");}}}}}sub array {my($ref,$string)=@_;my $i=0;
foreach (@$ref){unless(ref($_)){print$string,"[$i] = ", $_,"\n";}else{if(
ref($_)eq 'HASH'){&hash($_,"$string\[$i] -> ")}else{if(ref($_)eq'ARRAY'){
&array($_,"$string\[$i] -> ");}}}$i++;}}# n.d.p./2001-01-05/lm:2001-01-19
# FUNCTION: printing the configuration, USAGE: &Conf::Test::show ($conf);

#
#
### *real* end of Conf ;-) #####################################################