#!/usr/bin/perl -w

################################################################################
#                                                                              #
# File:        user/fo_arcview.pl                                              #
#                                                                              #
# Authors:     Frank Schoenmann <fs@tower.de>, 2001-06-02                      #
#                                                                              #
# Description: archive browser                                                 #
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
  $Shared  = "$Bin/../../cgi-shared";
  $Config  = "$Bin/../../cgi-config/forum";
  $Script  = ($null =~ /^.*\/(.*)$/)? $1 : $null;

#  my $null = $0; #$null =~ s/\\/\//g; # for win :-(
#  $Bin     = ($null =~ /^(.*)\/.*$/)? $1 : '.';
#  $Config  = "$Bin/../../../cgi-config/devforum";
#  $Shared  = "$Bin/../../../cgi-shared";
#  $Script  = ($null =~ /^.*\/(.*)$/)? $1 : $null;
}

use lib "$Shared";
use CGI::Carp qw(fatalsToBrowser);

use Conf;
use Conf::Admin;
use Template::Archive qw(
    print_month_as_HTML
    print_thread_as_HTML
);
#use Template::Forum;
#use Template::Posting;

use CGI qw(param header path_info);

print header(-type => 'text/html');

#my $show = $conf->{show};
#my $tree = $show->{assign}->{thread};

#my $forum_file = $conf->{files}->{forum};
#my $message_path = $conf->{files}->{messagePath};

my $conf = read_script_conf($Config, $Shared, $Script);
my $show = $conf->{'show'};
my $cgi = $show->{'assign'}->{'cgi'};
my $show_archive = $show->{'Archive'};
my $adminDefault = read_admin_conf($conf->{'files'}->{'adminDefault'});

my ($year, $month, $tid, $mid);

# tid is thread id, mid is not used yet
if (my $path_info = path_info()) {
    (undef, $year, $month, $tid, $mid) = split "/", $path_info;
} else {
    ($year, $month, $tid, $mid) =
        (param($cgi->{'year'}), param($cgi->{'month'}), param($cgi->{'thread'}), param($cgi->{'posting'}));
}

if ($year) {
    if ($month) {
        if ($tid) {
            if ($mid) {
#               print_msg_as_HTML();
            } else {
                print_thread_as_HTML(
                    $conf->{'files'}->{'archivePath'} . $year .'/'. $month .'/t'. $tid . '.xml',
#                   '/home/users/f/fo/fox_two/sf/data/forum/archive/2001/5/t23518',
                    $show_archive->{'templateFile'},
                    {
                        'assign'        => $show_archive->{'assign'},
                        'adminDefault'  => $adminDefault,
                        'cgi'           => $cgi,
                        'year'          => $year,
                        'month'         => $month,
                        'thread'        => $tid,
                        'posting'       => $mid,
                        'tree'          => $show->{'assign'}->{'thread'}

                    }
                );
            }
        } else {
            print_month_as_HTML(
                $conf->{'files'}->{'archivePath'} . $year . '/' . $month . '/' . $conf->{'files'}->{'archiveIndex'},
                $show_archive->{'templateFile'},
                {
                    'assign'        => $show_archive->{'assign'},
                    'year'          => $year,
                    'month'         => $month
                }
            );
        }
    } else {
#       print_year_as_HTML();
    }
} else {
#   print_overview_as_HTML();
}


#if (defined ($tid) and defined ($mid)) {
#  print_posting_as_HTML (
#    $message_path,
#    $show_posting -> {templateFile},
#    { assign       => $show_posting -> {assign},
#      thread       => $tid,
#      posting      => $mid,
#      adminDefault => $adminDefault,
#      messages     => $conf -> {template} -> {messages},
#      form         => $show_posting -> {form},
#      cgi          => $cgi,
#      tree         => $tree,
#      firsttime    => 1,
#      cachepath    => $conf -> {files} -> {cachePath}
#    }
#  );
#}
#
#else {
#  print_forum_as_HTML (
#    $forum_file,
#    $show_forum -> {templateFile},
#    { assign       => $show_forum -> {assign},
#      adminDefault => $adminDefault,
#      cgi          => $cgi,
#      tree         => $tree
#    }
#  );
#}

#
#
### end of fo_view.pl ##########################################################
