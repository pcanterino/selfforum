package Template::Forum;

################################################################################
#                                                                              #
# File:        shared/Template/Forum.pm                                        #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>, 2001-06-16                          #
#                                                                              #
# Description: print Forum main file to STDOUT                                 #
#                                                                              #
################################################################################

use strict;
use vars qw(
  @EXPORT
  $VERSION
);

use Lock qw(:READ);
use Encode::Plain; $Encode::Plain::utf8 = 1;
use Posting::_lib qw(
  get_all_threads
  long_hr_time
);
use Template;
use Template::_conf;
use Template::_thread;

################################################################################
#
# Version check
#
$VERSION = do { my @r =(q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

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
  my $assign = $param -> {assign};

  my $template = new Template $tempfile;

  my ($threads, $stat);

  unless ($stat = lock_file ($mainfile)) {
    if (defined $stat) {
      violent_unlock_file ($mainfile);
      print ${$template -> scrap (
        $assign -> {errorDoc},
        { $assign -> {errorText} => $template -> insert ($assign -> {'occupied'}) }
      )};
    }
    else {
      print ${$template -> scrap (
        $assign -> {errorDoc},
        { $assign -> {errorText} => $template -> insert ($assign -> {'notAvailable'}) }
      )};
    }}

  else {
    my $view = get_view_params (
      { adminDefault => $param -> {adminDefault} }
    );

    # set process priority, remove if you don't need...
    #
    eval {setpriority 0,0,1};

    $threads = get_all_threads ($mainfile, $param -> {showDeleted}, $view -> {sortedMsg});
    violent_unlock_file ($mainfile) unless (unlock_file ($mainfile));

    print ${$template -> scrap (
      $assign -> {mainDocStart},
      {  $assign -> {loadingTime} => plain (long_hr_time (time)) }
      )
    },"\n<dl>";

    my $tpar = {
      template => $param -> {tree},
      cgi      => $param -> {cgi},
      start    => -1
    };

    my @threads;

    unless ($view -> {sortedThreads}) {
      @threads = sort {$b <=> $a} keys %$threads;}
    else {
      @threads = sort {$a <=> $b} keys %$threads;}

    for (@threads) {
      $tpar -> {thread} = "$_";
      $|++;
      print ${html_thread ($threads -> {$_}, $template, $tpar)},"\n",'<dd>&nbsp;</dd>',"\n";}

    print "</dl>\n",${$template -> scrap ($assign -> {mainDocEnd})};}

  return;
}

# keep 'require' happy
1;

#
#
### end of Template::Forum #####################################################