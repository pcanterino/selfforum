#!/usr/bin/perl

use strict;

use vars qw($Bin $Shared $Script $t0);

BEGIN {
  ($Bin)    = ($0 =~ /^(.*)\/.*$/)? $1 : '.';
  $Shared   = "$Bin/../shared";
  ($Script) = ($0 =~ /^.*\/(.*)$/)? $1 : $0;}

use lib "$Shared";
use CGI::Carp qw(fatalsToBrowser);

use Conf;
use Conf::Admin;
use Template::Forum;
use Template::Posting;

use CGI qw(param header);

print header(-type => 'text/html');

my $conf = read_script_conf ($Bin, $Shared, $Script);

$conf -> {wwwRoot} = 'i:/i_selfhtml/htdocs' unless ($ENV{GATEWAY_INTERFACE} =~ /CGI/);

my $show = $conf -> {show};
my $show_forum = $show -> {Forum};
my $show_posting = $show -> {Posting};
my $cgi = $show -> {assign} -> {cgi};
my $tree = $show -> {assign} -> {thread};
my $adminDefault = read_admin_conf ("$Bin/".$conf -> {files} -> {adminDefault});

my $forum_file = $conf -> {wwwRoot}.$conf -> {files} -> {forum};
my $message_path = $conf -> {wwwRoot}.$conf -> {files} -> {messagePath};

#use Lock qw(:ALL);release_file(forum_file);die;

my ($tid, $mid) = (param ($cgi -> {thread}), param ($cgi -> {posting}));

if (defined ($tid) and defined ($mid)) {
  print_posting_as_HTML ($message_path,
                         "$Bin/".$show_posting -> {templateFile},
                        {assign       => $show_posting -> {assign},
                         thread       => $tid,
                         posting      => $mid,
                         adminDefault => $adminDefault,
                         messages     => $show_posting -> {messages},
                         form         => $show_posting -> {form},
                         cgi          => $cgi,
                         tree         => $tree
                        });}

else {
  print_forum_as_HTML ($forum_file,
                       "$Bin/".$show_forum -> {templateFile},
                      {assign       => $show_forum -> {assign},
                       adminDefault => $adminDefault,
                       cgi          => $cgi,
                       tree         => $tree
                      });}

print "t1 ";
# eos