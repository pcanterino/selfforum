#!/usr/bin/perl -w

################################################################################
#                                                                              #
# File:        user/fo_sev.pl                                                  #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>, 2001-04-08                          #
#                                                                              #
# Description: severancer script                                               #
#                                                                              #
################################################################################

use strict;
use vars qw(
  $Bin
  $Shared
  $Script
  $Config
  $VERSION
);

# locate the script
#
BEGIN {
  my $null = $0; $null =~ s/\\/\//g; # for win :-(
  $Bin     = ($null =~ /^(.*)\/.*$/)? $1 : '.';
  $Shared  = "$Bin/../shared";
  $Config  = "$Bin/config";
  $Script  = ($null =~ /^.*\/(.*)$/)? $1 : $null;

#  my $null = $0;
#  $Bin     = ($null =~ /^(.*)\/.*$/)? $1 : '.';
#  $Config  = "$Bin/../../daten/forum/config";
#  $Shared  = "$Bin/../../cgi-shared";
#  $Script  = ($null =~ /^.*\/(.*)$/)? $1 : $null;
}

# setting umask, remove or comment it, if you don't need
#
umask 006;

################################################################################
#
# Version check
#
$VERSION = do { my @r =(q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

use lib "$Shared";
use CGI::Carp qw(fatalsToBrowser);

use Arc::Archive;
use Conf;
use Conf::Admin;
use Posting::Cache;

# load script configuration and admin default conf.
#
my $conf         = read_script_conf ($Config, $Shared, $Script);
my $adminDefault = read_admin_conf ($conf -> {files} -> {adminDefault});

my $stat = cut_tail ({
  forumFile    => $conf->{files}->{forum},
  messagePath  => $conf->{files}->{messagePath},
  archivePath  => $conf->{files}->{archivePath},
  lockFile     => $conf->{files}->{sev_lock},
  adminDefault => $adminDefault,
  cachePath    => $conf->{files}->{cachePath}
});
#  die $stat->{(keys %$stat)[0]} if (%$stat);

#
#
### end of fo_sev.pl ###########################################################