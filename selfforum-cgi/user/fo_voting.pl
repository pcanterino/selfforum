#!/usr/bin/perl -w

################################################################################
#                                                                              #
# File:        user/fo_voting.pl                                               #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>                                      #
#                                                                              #
# Description: vote a posting, return the posting view                         #
#                                                                              #
################################################################################

use strict;
use vars qw(
  $Bin
  $Shared
  $Script
  $Config
);

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

use lib $Shared;
use CGI::Carp qw(fatalsToBrowser);

use Conf;
use Conf::Admin;
use Posting::Cache;
use Template::Posting;

use CGI qw(
  param
  header
  remote_addr
  request_method
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

my $conf = read_script_conf ($Config, $Shared, $Script);

my $show = $conf -> {show};
my $show_forum = $show -> {Forum};
my $show_posting = $show -> {Posting};
my $cgi = $show -> {assign} -> {cgi};
my $tree = $show -> {assign} -> {thread};
my $adminDefault = read_admin_conf ($conf -> {files} -> {adminDefault});

my $forum_file = $conf -> {files} -> {forum};
my $message_path = $conf -> {files} -> {messagePath};

my $formdata = $show_posting -> {form} -> {data};
my $fup  = param ($formdata -> {followUp} -> {name}) || '';
my $unid = param ($formdata -> {uniqueID} -> {name}) || '';
my $voted;

my ($tid, $mid) = map {$_ || 0} split /;/ => $fup, 2;

$tid = (defined $tid and $tid=~/(\d+)/)? $1: 0;
$mid = (defined $mid and $mid=~/(\d+)/)? $1: 0;

if ($tid and $mid and $unid) {

  print header(-type => 'text/html');

  my $cache = new Posting::Cache ($conf->{files}->{cachePath});
  my $hash;

  if ($hash = $cache -> pick ({thread => $tid, posting => $mid})) {
    unless (exists ($hash->{voteRef}->{$unid})) {

      $voted=1;
      my $ip = remote_addr;
      my %iphash = map {
        $hash->{voteRef}->{$_}->{IP} => $hash->{voteRef}->{$_}->{time}
      } keys %{$hash->{voteRef}};

      my $time = time;

      unless (exists($iphash{$ip}) and $iphash{$ip}>($time-$adminDefault->{Voting}->{voteLock}*60)) {
        if (request_method eq 'POST') {
          $cache -> add_voting (
            { posting => $mid,
              thread  => $tid,
              IP      => $ip,
              time    => $time,
              ID      => $unid
            }
          );# or die $cache->error;
        }
      }
    }
  }

  print_posting_as_HTML (
    $message_path,
    $show_posting -> {templateFile},
    { assign       => $show_posting -> {assign},
      thread       => $tid,
      posting      => $mid,
      adminDefault => $adminDefault,
      messages     => $conf -> {template} -> {messages},
      form         => $show_posting -> {form},
      cgi          => $cgi,
      tree         => $tree,
      voted        => $voted || '',
      cachepath    => $conf -> {files} -> {cachePath}
    }
  );
}
else {
  print header(-status => '204 No Response');
}

#
#
### end of fo_voting.pl ########################################################