#!/usr/bin/perl -w

################################################################################
#                                                                              #
# File:        user/fo_view.pl                                                 #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>, 2001-04-01                          #
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
#  my $null = $0; $null =~ s/\\/\//g; # for win :-(
#  $Bin     = ($null =~ /^(.*)\/.*$/)? $1 : '.';
#  $Shared  = "$Bin/../shared";
#  $Config  = "$Bin/config";
#  $Script  = ($null =~ /^.*\/(.*)$/)? $1 : $null;

  my $null = $0; #$null =~ s/\\/\//g; # for win :-(
  $Bin     = ($null =~ /^(.*)\/.*$/)? $1 : '.';
  $Config  = "$Bin/../../../cgi-config/devforum";
  $Shared  = "$Bin/../../../cgi-shared";
  $Script  = ($null =~ /^.*\/(.*)$/)? $1 : $null;
}

use lib "$Shared";
use CGI::Carp qw(fatalsToBrowser);

use Conf;
use Conf::Admin;
use Template::Forum;
use Template::Posting;

use CGI qw(param header);

print header(-type => 'text/html');

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
      cachefile    => $conf -> {files} -> {cacheFile}
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