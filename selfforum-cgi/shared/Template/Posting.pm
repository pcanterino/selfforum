# Template/Posting.pm

# ====================================================
# Autor: n.d.p. / 2001-01-14
# lm   : n.d.p. / 2001-01-14
# ====================================================
# Funktion:
#      HTML-Darstellung eines Postings
# ====================================================

use strict;

package Template::Posting;

use vars qw(@ISA @EXPORT);

use Encode::Posting;
use Encode::Plain; $Encode::Plain::utf8 = 1;
use Id;
use Lock qw(:WRITE);
use Posting::_lib qw(get_message_node get_message_header get_message_body parse_single_thread hr_time);
use Template;
use Template::_query;
use Template::_thread;

use XML::DOM;

# ====================================================
# Funktionsexport
# ====================================================

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(print_posting_as_HTML message_as_HTML);

################################
# sub print_posting_as_HTML
#
# HTML erzeugen
################################

sub print_posting_as_HTML ($$$) {
  my ($threadpath, $tempfile, $param) = @_;

  my $template = new Template $tempfile;

  # Datei sperren... (eigentlich)
  my $xml=new XML::DOM::Parser -> parsefile ($threadpath.'t'.$param -> {thread}.'.xml');

  my ($mnode, $tnode) = get_message_node ($xml, 't'.$param -> {thread}, 'm'.$param -> {posting});
  my $pnode = $mnode -> getParentNode;
  my $header = get_message_header ($mnode);
  my $msg = parse_single_thread ($tnode, 0, 0);
  my $pheader = ($pnode -> getNodeName eq 'Message')?get_message_header ($pnode):{};

  my $assign = $param -> {assign};
  my $formdata = $param -> {form} -> {data};
  my $formact = $param -> {form} -> {action};

  my $body = get_message_body ($xml, 'm'.$param -> {posting});

  my $text = message_field ($body,
                           {quoteChars => '&raquo;&raquo; ',
                            quoting    => 1,
                            startCite  => ${$template -> scrap ($assign -> {startCite})},
                            endCite    => ${$template -> scrap ($assign -> {endCite})}
                           });

  my $area = answer_field ($body,
                          {quoteArea  => 1,
                           quoteChars => '&raquo;&raquo; ',
                           messages   => $param -> {messages}
                          });

  my $pars = {};

  for (qw(posterBody uniqueID followUp quoteChar userID posterName posterEmail posterURL posterImage)) {
    $pars -> {$formdata -> {$_} -> {assign} -> {name}} = plain($formdata -> {$_} -> {name});}

  my $cgi = $param -> {cgi};

  my $tpar = {thread   => $param -> {thread},
              template => $param -> {tree},
              start    => $param -> {posting},
              cgi      => $cgi};

  my $plink = %$pheader?(query_string ({$cgi -> {thread} => $param -> {thread}, $cgi -> {posting} => ($pnode -> getAttribute ('id') =~ /(\d+)/)[0]})):'';

  print ${$template -> scrap ($assign->{mainDoc},
                             {$assign->{name}                            => plain($header->{name}),
                              $assign->{email}                           => plain($header->{email}),
                              $assign->{home}                            => plain($header->{home}),
                              $assign->{image}                           => plain($header->{image}),
                              $assign->{time}                            => plain(hr_time($header->{time})),
                              $assign->{message}                         => $text,
                              $assign->{messageTitle}                    => plain($header->{subject}),
                              $assign->{parentTitle}                     => plain($pheader->{subject}),
                              $assign->{messageCat}                      => plain($header->{category}),
                              $assign->{parentCat}                       => plain($pheader->{category}),
                              $assign->{parentName}                      => plain($pheader->{name}),
                              $assign->{parentLink}                      => $plink,
                              $assign->{parentTime}                      => plain(hr_time($pheader->{time})),
                              $param->{tree}->{main}                     => html_thread ($msg, $template, $tpar),
                              $formact->{post}->{assign}                 => $formact->{post}->{url},
                              $formact->{vote}->{assign}                 => $formact->{vote}->{url},
                              $formdata->{posterBody}->{assign}->{value} => $area,
                              $formdata->{uniqueID}  ->{assign}->{value} => plain(unique_id),
                              $formdata->{followUp}  ->{assign}->{value} => plain($param -> {thread}.';'.$param -> {posting}),
                              $formdata->{quoteChar} ->{assign}->{value} => "&#255;".plain('»» '),
                              $formdata->{userID}    ->{assign}->{value} => '',
                              }, $pars)};

}

################################
# sub message_as_HTML
#
# HTML erzeugen
################################

sub message_as_HTML ($$$) {
  my ($xml, $template, $param) = @_;

  my $assign = $param -> {assign};
  my $body = get_message_body ($xml, $param -> {posting});

  my $text = message_field ($body,
                           {quoteChars => '&raquo;&raquo; ',
                            quoting    => 1,
                            startCite  => ${$template -> scrap ($assign -> {startCite})},
                            endCite    => ${$template -> scrap ($assign -> {endCite})}
                           });

  # Rueckgabe
  $text;
}

# ====================================================
# Modulinitialisierung
# ====================================================

# making require happy
1;

# ====================================================
# end of Template::Posting
# ====================================================