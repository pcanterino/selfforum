package Template::_thread;

################################################################################
#                                                                              #
# File:        shared/Template/_thread.pm                                      #
#                                                                              #
# Authors:     Andre Malo <nd@o3media.de>, 2001-04-02                          #
#                                                                              #
# Description: convert parsed thread to HTML                                   #
#                                                                              #
################################################################################

use strict;

use Encode::Plain; $Encode::Plain::utf8 = 1;
use Posting::_lib qw(short_hr_time);
use Template;
use Template::_query;

################################################################################
#
# Export
#
use base qw(Exporter);
@Template::_thread::EXPORT = qw(html_thread);

### sub html_thread ($$$) ######################################################
#
# create HTML string
#
# Params: $msg      - Reference of Message-Array
#                     (Output of parse_single_thread in Posting::_lib)
#         $template - Template object
#         $par      - Hash Reference (see doc for details)
#
# Return: Reference of HTML String
#
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

  # whole thread
  if ($par -> {start} == -1) {
    $_ = $msg -> [0];
    @indexes = (1..$_ -> {answers});

    if ($_ -> {answers}) {
      $html =
        '<dd><dl><dt>'.

        ${$template -> scrap (
           $temp -> {
             length $_ -> {cat}
               ? 'start'
               : 'startNC'
           },
           { $temp -> {name}    => $_ -> {name},
             $temp -> {subject} => $_ -> {subject},
             $temp -> {cat}     => $_ -> {cat},
             $temp -> {time}    => plain(short_hr_time ($_ -> {time})),
             $temp -> {link}    => query_string({$t => $tid, $p => $_ -> {mid}})
           },
           $par -> {addParam}
          )} .
        '</dt>';
    }

    else {
      $html =
        '<dd>'.
        ${$template -> scrap (
           $temp -> {
             length $_ -> {cat}
             ? 'start'
             : 'startNC'
           },
           { $temp -> {name}    => $_ -> {name},
             $temp -> {subject} => $_ -> {subject},
             $temp -> {cat}     => $_ -> {cat},
             $temp -> {time}    => plain(short_hr_time ($_ -> {time})),
             $temp -> {link}    => query_string({$t => $tid, $p => $_ -> {mid}})
           },
           $par -> {addParam}
          )}.
        '</dd>';

      return \$html;
    }
  }

  # only subthread
  #
  else {
    my $start=-1;
    for (@$msg) {$start++; last if ($_ -> {mid} == $par -> {start});}
    my $end   = $start + $msg -> [$start] -> {answers};
    $start++;
    @indexes = ($start..$end);
    $oldlevel = $startlevel = $msg -> [$start] -> {level}
      if (defined $msg -> [$start] -> {level});
  }

  # create HTML
  #
  for (@$msg[@indexes]) {

    if ($_ -> {level} < $oldlevel) {
      $html.='</dl></dd>' x ($oldlevel - $_ -> {level});}

    $oldlevel = $_ -> {level};

    if ($_ -> {answers}) {
      $html.=
        '<dd><dl><dt>'.
        ${$template -> scrap (
           $temp -> {
             length $_ -> {cat}
             ? 'line'
             : 'lineNC'
           },
           { $temp -> {name}    => $_ -> {name},
             $temp -> {subject} => $_ -> {subject},
             $temp -> {cat}     => $_ -> {cat},
             $temp -> {time}    => plain(short_hr_time ($_ -> {time})),
             $temp -> {link}    => query_string({$t => $tid, $p => $_ -> {mid}})
           },
           $par -> {addParam}
          )}.
        '</dt>';
    }
    else {
      $html.=
        '<dd>'.
        ${$template -> scrap (
           $temp -> {
             length $_ -> {cat}
             ? 'line'
             : 'lineNC'
           },
           { $temp -> {name}    => $_ -> {name},
             $temp -> {subject} => $_ -> {subject},
             $temp -> {cat}     => $_ -> {cat},
             $temp -> {time}    => plain(short_hr_time ($_ -> {time})),
             $temp -> {link}    => query_string({$t => $tid, $p => $_ -> {mid}})
           },
           $par -> {addParam}
          )}.
        '</dd>';
    }
  }
  $html.='</dl></dd>' x ($oldlevel - $startlevel);

  \$html;
}

# keep require happy
1;

#
#
### end of Template::_thread ###################################################