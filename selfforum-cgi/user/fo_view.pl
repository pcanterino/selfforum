#!/usr/bin/perl -w

################################################################################
#                                                                              #
# File:        user/fo_view.pl                                                 #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>                                      #
#                                                                              #
# Description: display the forum main file or a single posting                 #
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

use lib "$Shared";
use CGI::Carp qw(fatalsToBrowser);

use Conf;
use Conf::Admin;
use Template::Forum;
use Template::Posting;

use CGI qw(
  param
  header
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

print header(
  -type    => 'text/html',
  -expires => '+10m'
);

my $conf = read_script_conf ($Config, $Shared, $Script);

my $show = $conf -> {show};
my $show_forum = $show -> {Forum};
my $show_posting = $show -> {Posting};
my $cgi = $show -> {assign} -> {cgi};
my $tree = $show -> {assign} -> {thread};
my $adminDefault = read_admin_conf ($conf -> {files} -> {adminDefault});

my $forum_file = $conf -> {files} -> {forum};
my $message_path = $conf -> {files} -> {messagePath};

my ($tid, $mid) = (param ($cgi -> {thread}), param ($cgi -> {posting}));

if (defined ($tid) and defined ($mid)) {
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
      firsttime    => 1,
      cachepath    => $conf -> {files} -> {cachePath}
    }
  );
}

else {
  print_forum_as_HTML (
    $forum_file,
    $show_forum -> {templateFile},
    { assign       => $show_forum -> {assign},
      adminDefault => $adminDefault,
      cgi          => $cgi,
      tree         => $tree
    }
  );
}

#
#
### end of fo_view.pl ##########################################################