# Template/_thread.pm

# ====================================================
# Autor: n.d.p. / 2001-01-11
# lm   : n.d.p. / 2001-01-11
# ====================================================
# Funktion:
#      HTML-Darstellung eines Threads
# ====================================================

use strict;

package Template::_thread;

use vars qw(@ISA @EXPORT);

use Encode::Plain; $Encode::Plain::utf8 = 1;
use Posting::_lib qw(short_hr_time);
use Template;
use Template::_query;

# ====================================================
# Funktionsexport
# ====================================================

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(html_thread);

################################
# sub html_thread
#
# Thread erzeugen
################################

sub html_thread ($$$) {
  my ($msg, $template, $par) = @_;

  return \'' unless @$msg;

  my $temp = $par -> {template};
  my $i = $par -> {cgi} -> {user};
  my $t = $par -> {cgi} -> {thread};
  my $p = $par -> {cgi} -> {posting};
  my $c = $par -> {cgi} -> {command};
  my $tid = $par -> {thread};
  my $html='';
  my $startlevel=0;
  my $oldlevel=0;
  my @indexes;

  # ganzer Thread
  if ($par -> {start} == -1) {
    $_ = $msg -> [0];
    @indexes = (1..$_ -> {answers});

    if ($_ -> {answers}) {
      $html = '<dd><dl><dt>'
              .${$template -> scrap ($temp -> {(length $_ -> {cat})?'start':'startNC'},
                                    {$temp -> {name}    => $_ -> {name},
                                     $temp -> {subject} => $_ -> {subject},
                                     $temp -> {cat}     => $_ -> {cat},
                                     $temp -> {time}    => plain(short_hr_time ($_ -> {time})),
                                     $temp -> {link}    => query_string({$t => $tid, $p => $_ -> {mid}})},
                                     $par -> {addParam})}
              .'</dt>';}

    else {
      $html = '<dd>'
              .${$template -> scrap ($temp -> {(length $_ -> {cat})?'start':'startNC'},
                                    {$temp -> {name}    => $_ -> {name},
                                     $temp -> {subject} => $_ -> {subject},
                                     $temp -> {cat}     => $_ -> {cat},
                                     $temp -> {time}    => plain(short_hr_time ($_ -> {time})),
                                     $temp -> {link}    => query_string({$t => $tid, $p => $_ -> {mid}})},
                                     $par -> {addParam})}
              .'</dd>';

      return \$html;}}

  # Teilthread
  else {
    my $start=-1;
    for (@$msg) {$start++; last if ($_ -> {mid} == $par -> {start});}
    my $end   = $start + $msg -> [$start] -> {answers};
    $start++;
    @indexes = ($start..$end);
    $oldlevel = $startlevel = $msg -> [$par -> {start}] -> {level};}

  # HTML erzeugen
  for (@$msg[@indexes]) {

    if ($_ -> {level} < $oldlevel) {
      $html.='</dl></dd>' x ($oldlevel - $_ -> {level});}

    $oldlevel = $_ -> {level};

    if ($_ -> {answers}) {
      $html.='<dd><dl><dt>'
             .${$template -> scrap ($temp -> {(length $_ -> {cat})?'line':'lineNC'},
                                   {$temp -> {name}    => $_ -> {name},
                                   $temp -> {subject} => $_ -> {subject},
                                   $temp -> {cat}     => $_ -> {cat},
                                   $temp -> {time}    => plain(short_hr_time ($_ -> {time})),
                                   $temp -> {link}    => query_string({$t => $tid, $p => $_ -> {mid}})},
                                   $par -> {addParam})}
             .'</dt>';
    }
    else {
      $html.='<dd>'
             .${$template -> scrap ($temp -> {(length $_ -> {cat})?'line':'lineNC'},
                                   {$temp -> {name}    => $_ -> {name},
                                   $temp -> {subject} => $_ -> {subject},
                                   $temp -> {cat}     => $_ -> {cat},
                                   $temp -> {time}    => plain(short_hr_time ($_ -> {time})),
                                   $temp -> {link}    => query_string({$t => $tid, $p => $_ -> {mid}})},
                                   $par -> {addParam})}
             .'</dd>';
    }
  }

  $html.='</dl></dd>' x ($oldlevel - $startlevel);

  \$html;
}

# ====================================================
# Modulinitialisierung
# ====================================================

# making require happy
1;

# ====================================================
# end of Template::_thread
# ====================================================