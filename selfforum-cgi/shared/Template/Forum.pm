# Template/Forum.pm

# ====================================================
# Autor: n.d.p. / 2001-01-12
# lm   : n.d.p. / 2001-01-12
# ====================================================
# Funktion:
#      Erzeugung der HTML-Ausgabe der
#      Forumshauptdatei
# ====================================================

use strict;

package Template::Forum;

use Lock qw(:READ);
use Encode::Plain; $Encode::Plain::utf8 = 1;
use Posting::_lib qw(get_all_threads long_hr_time);
use Template;
use Template::_conf;
use Template::_thread;

# ====================================================
# Funktionsexport
# ====================================================

use base qw(Exporter);
@Template::Forum::EXPORT = qw(print_forum_as_HTML);

################################
# sub print_forum_as_HTML
#
# HTML erstellen
################################

sub print_forum_as_HTML ($$$) {
  my ($mainfile, $tempfile, $param) = @_;
  my $assign = $param -> {assign};

  my $template = new Template $tempfile;

  my ($threads, $stat);

  unless ($stat = lock_file ($mainfile)) {
    if ($stat == 0) {
      violent_unlock_file ($mainfile);
      print "aha!"
      # ueberlastet
    }

    else {
     # Mastersperre...
    }}

  else {
    my $view = get_view_params ({adminDefault => $param -> {adminDefault}
                               });

    $threads = get_all_threads ($mainfile, $param -> {showDeleted}, $view -> {sortedMsg});
    violent_unlock_file ($mainfile) unless (unlock_file ($mainfile));

    print ${$template -> scrap ($assign -> {mainDocStart},
                               {$assign -> {loadingTime} => plain (long_hr_time (time)) } )},"\n<dl>";

    my $tpar = {template => $param -> {tree},
                cgi      => $param -> {cgi},
                start    => -1};

    my @threads;

    unless ($view -> {sortedThreads}) {
      @threads = sort {$b <=> $a} keys %$threads;}
    else {
      @threads = sort {$a <=> $b} keys %$threads;}

    for (@threads) {
      $tpar -> {thread} = "$_";
      print ${html_thread ($threads -> {$_}, $template, $tpar)},"\n",'<dd>&nbsp;</dd>',"\n";}

    print "</dl>\n",${$template -> scrap ($assign -> {mainDocEnd})};}

  return;
}

# ====================================================
# Modulinitialisierung
# ====================================================

# making require happy
1;

# ====================================================
# end of Template::Forum
# ====================================================