package Template::_thread;

################################################################################
#                                                                              #
# File:        shared/Template/_thread.pm                                      #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>                                      #
#              Christian Kruse <ckruse@wwwtech.de>                             #
#                                                                              #
# Description: convert parsed thread to HTML                                   #
#                                                                              #
################################################################################

use strict;
use vars qw(
  @EXPORT
);

use Encode::Plain; $Encode::Plain::utf8 = 1;
use Posting::_lib qw(short_hr_time);
use Template;
use Template::_query;
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
@EXPORT = qw(html_thread);

### html_thread () #############################################################
#
# create HTML string
#
# Params: $msg       Reference of Message-Array
#                     (Output of parse_single_thread in Posting::_lib)
#         $template  Template object
#         $par       Hash Reference (see doc for details)
#         $params    Additional parameters
#
# Return: Reference of HTML String
#
sub html_thread ($$$;$) {
  my ($msg, $template, $par, $params) = @_;
  my $additionalVariables = $params->{'additionalVariables'} || {};
  my $actions             = {
    'action'        => $params->{'action'},
    'actionDeleted' => $params->{'actionDeleted'}
  };
  my $base = $params->{'base_link'};

  return \'' unless @$msg;

  my $temp = $par->{'template'};
  my $i = $par->{'cgi'}->{'user'};
  my $t = $par->{'cgi'}->{'thread'};
  my $p = $par->{'cgi'}->{'posting'};
  my $c = $par->{'cgi'}->{'command'};
  my $tid = $par->{'thread'};
  my $html = '';
  my $startlevel = 0;
  my $oldlevel = 0;
  my @indexes;

  # whole thread
  if ($par->{'start'} == -1) {
    $_ = $msg->[0];
    @indexes = (1 .. $_->{answers});

    my $del = $_->{deleted} ? 'Deleted' : '';
    my $action = $actions->{'action'.$del}; $action =~ s/\Q{mid}\E/$_->{mid}/g;

    if ($_->{answers}) {
      $html =
        '<dd><dl><dt>'.

        ${$template->scrap(
           $temp->{
             (length $_->{'cat'}
               ? 'start'
               : 'startNC').$del
           },
           { $temp->{'name'}    => $_->{'name'},
             $temp->{'subject'} => $_->{'subject'},
             $temp->{'cat'}     => $_->{'cat'},
             $temp->{'time'}    => plain(short_hr_time($_->{'time'})),
             $temp->{'link'}    => $base.query_string({$t => $tid, $p => $_->{'mid'}}),
             $temp->{'tid'}     => $tid,
             $temp->{'mid'}     => $_->{'mid'},
             $temp->{'command'} => $action,
             %{$additionalVariables}
           },
           $par->{'addParam'}
          )} .
        '</dt>';
    }

    else {
      $html =
        '<dd>'.
        ${$template->scrap(
           $temp->{
             (length $_->{'cat'}
              ? 'start'
              : 'startNC').$del
           },
           { $temp->{'name'}    => $_->{'name'},
             $temp->{'subject'} => $_->{'subject'},
             $temp->{'cat'}     => $_->{'cat'},
             $temp->{'time'}    => plain(short_hr_time ($_->{'time'})),
             $temp->{'link'}    => $base.query_string({$t => $tid, $p => $_->{'mid'}}),
             $temp->{'tid'}     => $tid,
             $temp->{'mid'}     => $_->{'mid'},
             $temp->{'command'} => $action,
             %{$additionalVariables}
           },
           $par->{'addParam'}
          )}.
        '</dd>';

      return \$html;
    }
  }

  # only subthread
  #
  else {
    my $start = -1;
    for (@$msg) { $start++; last if ($_->{'mid'} == $par->{'start'}); }
    my $end = $start + $msg->[$start]->{'answers'};
    $start++;
    @indexes = ($start .. $end);
    $oldlevel = $startlevel = $msg->[$start]->{'level'}
      if (defined $msg->[$start]->{'level'});
  }

  # create HTML
  #
  for (@$msg[@indexes]) {
    my $del    = $_->{'deleted'} ? 'Deleted' : '';
    my $action = $actions->{'action'.$del}; $action =~ s/\Q{mid}\E/$_->{mid}/g;

    if ($_->{'level'} < $oldlevel) {
      $html .= '</dl></dd>' x ($oldlevel - $_->{'level'});
    }

    $oldlevel = $_->{'level'};

    if ($_->{'answers'}) {
      $html .=
        '<dd><dl><dt>'.
        ${$template->scrap(
           $temp->{
             (length $_->{'cat'}
             ? 'line'
             : 'lineNC').$del
           },
           { $temp->{'name'}    => $_->{'name'},
             $temp->{'subject'} => $_->{'subject'},
             $temp->{'cat'}     => $_->{'cat'},
             $temp->{'time'}    => plain(short_hr_time ($_->{'time'})),
             $temp->{'link'}    => $base.query_string({$t => $tid, $p => $_->{'mid'}}),
             $temp->{'tid'}     => $tid,
             $temp->{'mid'}     => $_->{'mid'},
             $temp->{'command'} => $action,
             %{$additionalVariables}
           },
           $par->{'addParam'}
          )}.
        '</dt>';
    }
    else {
      $html .=
        '<dd>'.
        ${$template->scrap(
           $temp->{
             (length $_->{'cat'}
             ? 'line'
             : 'lineNC').$del
           },
           { $temp->{'name'}    => $_->{'name'},
             $temp->{'subject'} => $_->{'subject'},
             $temp->{'cat'}     => $_->{'cat'},
             $temp->{'time'}    => plain(short_hr_time ($_->{'time'})),
             $temp->{'link'}    => $base.query_string({$t => $tid, $p => $_->{'mid'}}),
             $temp->{'tid'}     => $tid,
             $temp->{'mid'}     => $_->{'mid'},
             $temp->{'command'} => $action,
             %{$additionalVariables}
           },
           $par->{'addParam'}
          )}.
        '</dd>';
    }
  }
  $html .= '</dl></dd>' x ($oldlevel - $startlevel);

  \$html;
}

# keep 'require' happy
1;

#
#
### end of Template::_thread ###################################################
