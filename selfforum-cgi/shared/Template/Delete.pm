package Template::Delete;

################################################################################
#                                                                              #
# File:        shared/Template/Delete.pm                                       #
#                                                                              #
# Authors:     Christian Kruse <ckruse@wwwtech.de>                             #
#                                                                              #
# Description: 'Administrator' view of forum index for deleting msgs           #
#                                                                              #
################################################################################

use strict;
use vars qw(
  @EXPORT
);

use Lock;
use Encode::Plain; $Encode::Plain::utf8 = 1;
use Posting::_lib qw(
  get_all_threads
  long_hr_time
);
use Template;
use Template::_conf;
use Template::_thread;
use Data::Dumper;

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
@EXPORT = qw(print_forum_as_HTML);

### print_forum_as_HTML () #####################################################
#
# print Forum main file to STDOUT
#
# Params: $mainfile - main xml file name
#         $tempfile - template file name
#         $param    - hash reference (see doc for details)
#
# Return: ~none~
#
sub print_forum_as_HTML ($$$) {
  my ($mainfile, $tempfile, $param) = @_;
  my $assign = $param->{assign};

  my $template = new Template $tempfile;

  my ($threads, $stat);
  my $main = new Lock ($mainfile);

  unless ($main->lock (LH_SHARED)) {
    unless ($main->masterlocked) {
      print ${$template->scrap (
        $assign->{errorDoc},
        { $assign->{errorText} => $template->insert ($assign->{'occupied'}) }
      )};
    }
    else {
      print ${$template->scrap (
        $assign->{errorDoc},
        { $assign->{errorText} => $template->insert($assign->{'notAvailable'}) }
      )};
    }}

  else {
    my $view = get_view_params (
      { adminDefault => $param->{adminDefault} }
    );

    # set process priority, remove if you don't need...
    #
    eval {setpriority 0,0,1};

    $threads = get_all_threads($main->filename, $param->{showDeleted}, $view->{sortedMsg});
    $main->unlock;

    print ${$template->scrap (
      $assign->{mainDocStart},
      { $assign->{loadingTime} => plain(long_hr_time (time)) }
      )
    },"\n<dl>";

    my $tpar = {
      template => $param->{tree},
      cgi      => $param->{cgi},
      start    => -1
    };

    my @threads;

    unless ($view->{sortedThreads}) {
      @threads = sort {$b <=> $a} keys %$threads;
    }
    else {
      @threads = sort {$a <=> $b} keys %$threads;
    }

    for (@threads) {
      $tpar->{thread} = "$_";

      print ${
        html_thread(
          $threads->{$_}, $template, $tpar, {
            action        => '<a href="fo_delete.pl?m={mid}&t='.$_.'&c=d"><b>L&ouml;schen</b></a>',
            actionDeleted => '<a href="fo_delete.pl?m={mid}&t='.$_.'&c=w"><b>Wiederherstellen</b></a>',
            base_link     => 'fo_delete.pl'
          }
        )
      },"\n",'<dd>&nbsp;</dd>',"\n";
    }

    print "</dl>\n",${$template->scrap($assign->{mainDocEnd})};}

  return;
}

# keep 'require' happy
1;

#
#
### end of Template::Forum #####################################################
