# Conf.pm

# ====================================================
# Autor: n.d.p. / 2001-01-05
# lm   : n.d.p. / 2001-02-02
# ====================================================
# Funktion:
#      Einlesen der Scriptkonfiguration
# ====================================================

use strict;

package Conf;

use vars qw(@ISA @EXPORT);

use XML::DOM;

# ====================================================
# Funktionsexport
# ====================================================

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(read_script_conf);

################################
# sub read_script_conf
#
# Scriptkonf. lesen
################################

sub read_script_conf ($$$) {
  my ($Bin, $Shared, $Script) = @_;

  $Script =~ s/^(.*)\..*$/$1/;             # Vornamen extrahieren
  my $common  = "$Shared/common.xml";      # gemeinsame Konf-datei
  my $group   = "$Bin/config/common.xml";  # gemeinsame (Gruppen-)Konf-datei
  my $special = "$Bin/config/$Script.xml"; # spezielle Konf-datei
  my %conf=();                             # conf-Hash

  &parse_script_conf ($common , \%conf, $Script);   # und los...
  &parse_script_conf ($group,   \%conf, $Script);
  &parse_script_conf ($special, \%conf, $Script);

  # Rueckgabe
  \%conf;
}

# ====================================================
# Private Funktionen
# ====================================================

sub parse_script_conf ($$$) {
  my ($filename, $conf, $Script) = @_;

  if (-f $filename) {
    # XML parsen
    my $xml = new XML::DOM::Parser -> parsefile ($filename);
    my $config = $xml -> getElementsByTagName ('Config',0) -> item (0);

    foreach ($config -> getElementsByTagName ('Constant', 0)) {&add_data ($_, $conf)}
    foreach ($config -> getElementsByTagName ('Property', 0)) {&add_prop ($_, $conf)}
    foreach ($config -> getElementsByTagName ('Limit', 0))    {&add_limit ($_, $conf, $Script)}}

  return;
}

sub add_data ($$) {
  my ($node, $conf) = @_;
  my $name = $node -> getAttribute ('name');

  die "element '".$node -> getNodeName."' requires attribute 'name' - aborted" unless (length ($name) and defined ($name));
  die "double defined name '$name' - aborted" if ( exists ( $conf -> {$name} ) );

  # Wert eintragen
  $conf -> {$name} = ($node -> hasChildNodes)?$node -> getFirstChild -> getData:undef;

  return;
}

sub add_prop ($$) {
  my ($node, $conf) = @_;

  my $name = $node -> getAttribute ('name');

  die "element 'Property' requires attribute 'name' - aborted" unless (length ($name));

  my @props  = $node -> getElementsByTagName ('Property', 0);
  my @vars = $node -> getElementsByTagName ('Variable', 0);
  my @lists  = $node -> getElementsByTagName ('List', 0);

  # Properties
  if (@props) {
    for (@props) {
      my $hash = (defined $conf -> {$name})?$conf -> {$name}:{};

      die "name '$name' is defined for 'Property' and 'Variable' - aborted" unless (ref $hash eq 'HASH');

      &add_prop ($_, $hash);
      $conf -> {$name} = $hash;}}

  # Array
  if (@lists) {
    for (@lists) {
      my $lname = $_ -> getAttribute ('name');

      die "element 'List' requires attribute 'name' - aborted" unless (length ($lname) and defined ($lname));
      die "double defined name '$lname' - aborted" if ( exists ( $conf -> {$name} -> {$lname} ) );

      $conf -> {$name} -> {$lname} = [map {($_ -> hasChildNodes)?$_ -> getFirstChild -> getData:undef} $_ -> getElementsByTagName ('ListItem', 0)];}}

  # Hash
  if (@vars) {
    for (@vars) {
      my $vname = $_ -> getAttribute ('name');

      die "element 'Variable' requires attribute 'name' - aborted" unless (length ($vname) and defined ($vname));
      die "double defined name '$vname' - aborted" if ( exists ( $conf -> {$name} -> {$vname} ) );

      $conf -> {$name} -> {$vname} = ($_ -> hasChildNodes)?$_ -> getFirstChild -> getData:undef;}}

  return;
}

sub add_limit ($$$) {
  my ($node, $conf, $Script) = @_;

  my %apps = map {($_ -> getFirstChild -> getData => 1)}
                   $node -> getElementsByTagName ('Application',0) -> item (0)
                   -> getElementsByTagName ('Script',0);

  if ($apps {$Script}) {
    foreach ($node -> getElementsByTagName ('Constant', 0)) {&add_data ($_, $conf)}
    foreach ($node -> getElementsByTagName ('Property', 0)) {&add_prop ($_, $conf)}}

  return;
}

# ====================================================
# Modulinitialisierung
# ====================================================

# making require happy
1;

# ====================================================
# end of Conf
# ====================================================

package Conf::Test;sub show{print"Content-type: text/plain\n\n";&hash($_[
0],'')}sub hash{my($ref,$string)=@_;foreach(sort keys%$ref){my$val=$ref->
{$_};unless(ref($val)){print$string,$_,' = ',$val,"\n";next;}else{if(ref(
$val)eq 'HASH'){&hash($val,"$string$_ -> ");}else{if(ref($val)eq'ARRAY'){
&array($val,"$string$_ -> ");}}}}}sub array {my($ref,$string)=@_;my $i=0;
foreach (@$ref){unless(ref($_)){print$string,"[$i] = ", $_,"\n";}else{if(
ref($_)eq 'HASH'){&hash($_,"$string\[$i] -> ")}else{if(ref($_)eq'ARRAY'){
&array($_,"$string\[$i] -> ");}}}$i++;}}# n.d.p./2001-01-05/lm:2001-01-19
# FUNCTION: printing the configuration, USAGE: &Conf::Test::show ($conf);

# ====================================================
# 'real' end of Conf .-))
# ====================================================