#!/usr/bin/perl -w

################################################################################
#                                                                              #
# File:        user/fo_arcview.pl                                              #
#                                                                              #
# Authors:     Frank Schönmann <fs@tower.de>                                   #
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
use Template::Archive qw(
    print_overview_as_HTML
    print_year_as_HTML
    print_month_as_HTML
    print_thread_as_HTML
);

use CGI qw(param header path_info);

################################################################################
#
# Version check
#
# last modified:
#    $Date$ (GMT)
# by $Author$
#
sub VERSION {(q$Revision$ =~ /([\d.]+)\s*$/)[0] or '0.0'}

print header(-type => 'text/html');

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
        print_year_as_HTML(
            $conf->{'files'}->{'archivePath'} . $year . '/',
            $show_archive->{'templateFile'},
            {
                'assign'        => $show_archive->{'assign'},
                'year'          => $year
            }
        );
    }
} else {
    print_overview_as_HTML(
        $conf->{'files'}->{'archivePath'},
        $show_archive->{'templateFile'},
        {
            'assign'        => $show_archive->{'assign'}
        }
    );
}

#
#
### end of fo_view.pl ##########################################################