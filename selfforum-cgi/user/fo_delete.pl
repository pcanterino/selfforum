#!/usr/bin/perl -w

################################################################################
#                                                                              #
# File:        user/admin/fo_delete.pl                                         #
#                                                                              #
# Authors:     Christian Kruse <ckruse@wwwtech.de>                             #
#                                                                              #
# Description: display the forum main file to delete msgs                      #
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
  my $null = $0; $null =~ s/\\/\//g if uc $^O eq 'WIN32'; # for win :-(
  $Bin     = ($null =~ /^(.*)\/.*$/)? $1 : '.';
  $Shared  = "$Bin/../shared";
  $Config  = "$Bin/../../cgi-config";
  $Script  = ($null =~ /^.*\/(.*)$/)? $1 : $null;
}

# setting umask, remove or comment it, if you don't need
#
umask 006;

use lib "$Shared";
use CGI::Carp qw(fatalsToBrowser);

use Conf;
use Conf::Admin;
use Template::Delete;
use Template::Posting;

use Posting::Admin;
use Encode::Plain; $Encode::Plain::utf8 = 1;
use Posting::_lib qw(
  parse_xml_file
  get_message_node
  get_message_header
  long_hr_time
);

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
  -expires => 'now'
);

my $conf = read_script_conf($Config, $Shared, $Script);

my $show = $conf->{show};
my $show_forum = $show->{Forum};

my $forum_file = $conf->{files}->{forum};

# check on closed forum
#
my $main = new Lock($forum_file);
if ($main->masterlocked) {

  my $template = new Template $show_forum->{templateFile};

  $template->printscrap (
    $show_forum->{assign}->{errorDoc},
    { $show_forum->{assign}->{errorText} => $template->insert($show_forum->{assign}->{'notAvailable'}) }
  );
}

else {
  my $cgi = $show->{assign}->{cgi};
  my $tree = $show->{assign}->{thread};

  my $adminDefault = read_admin_conf($conf->{files}->{adminDefault});

  my ($tid, $mid, $cmd) = (param($cgi->{thread}), param($cgi->{posting}), param('c'));

  if(defined $cmd and defined $mid and defined $tid) {
    if($cmd eq 'd') {
      unless(hide_posting($forum_file,$conf->{files}->{messagePath},{'thread' => $tid, 'posting' => $mid})) {
        my $template = new Template $show_forum->{templateFile};
        $template->printscrap(
          $show_forum->{assign}->{errorDoc},
          { $show_forum->{assign}->{errorText} => $template->insert($show_forum->{assign}->{deleteFailed}) }
        );
      }
      else {
        my $template = new Template $show_forum->{templateFile};
        my $xmlfile  = parse_xml_file($conf->{files}->{messagePath}.'/t'.$tid.'.xml');
        my $mnode    = get_message_node($xmlfile,'t'.$tid,'m'.$mid);
        my $infos    = get_message_header($mnode);
        my $ip       = $mnode->getAttribute('ip');

        $template->printscrap(
          $show_forum->{assign}->{deletedDoc},{
            $show_forum->{assign}->{tid}         => $tid,
            $show_forum->{assign}->{mid}         => $mid,
            $show->{assign}->{thread}->{cat}     => plain($infos->{category}),
            $show->{assign}->{thread}->{subject} => plain($infos->{subject}),
            $show->{assign}->{thread}->{time}    => plain(long_hr_time($infos->{time})),
            $show->{assign}->{thread}->{name}    => plain($infos->{name}),
            $show->{Posting}->{assign}->{email}  => plain($infos->{email}),
            $show_forum->{assign}->{ip}          => plain($ip)
          }
        );

        exit 0;
      }
    } elsif($cmd eq 'w') {
      unless(recover_posting($forum_file,$conf->{files}->{messagePath},{'thread' => $tid, 'posting' => $mid})) {
        my $template = new Template $show_forum->{templateFile};
        $template->printscrap(
          $show_forum->{assign}->{errorDoc},
          { $show_forum->{assign}->{errorText} => $template->insert($show_forum->{assign}->{recoverFailed}) }
        );
      } else {
        print_forum_as_HTML (
          $forum_file,
          $show_forum->{templateFile}, {
            showDeleted  => 1,
            assign       => $show_forum->{assign},
            adminDefault => $adminDefault,
            cgi          => $cgi,
            tree         => $tree
          }
        );
      }
    }
  }
  elsif (defined ($tid) and defined ($mid)) {
    my $show_posting = $show->{Posting};

    print_posting_as_HTML (
      $conf->{files}->{messagePath},
      $show_posting->{templateFile}, {
        assign       => $show_posting->{assign},
        thread       => $tid,
        posting      => $mid,
        adminDefault => $adminDefault,
        messages     => $conf->{template}->{messages},
        form         => $show_posting->{form},
        cgi          => $cgi,
        tree         => $tree,
        firsttime    => 1,
        cachepath    => $conf->{files}->{cachePath},
        showDeleted  => 1
      }
    );
  }

  else {
    print_forum_as_HTML (
      $forum_file,
      $show_forum->{templateFile}, {
        showDeleted  => 1,
        assign       => $show_forum->{assign},
        adminDefault => $adminDefault,
        cgi          => $cgi,
        tree         => $tree
      }
    );
  }
}


#
#
### end of fo_view.pl ##########################################################
