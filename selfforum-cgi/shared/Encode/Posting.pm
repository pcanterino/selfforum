# Posting.pm

# ====================================================
# Autor: n.d.p. / 2001-01-07
# lm   : n.d.p. / 2001-02-25
# ====================================================
# Funktion:
#      Spezielle Codierung eines Postingtextes
# ====================================================

use strict;

package Encode::Posting;

use vars qw(@EXPORT);
use Encode::Plain; $Encode::Plain::utf8 = 1;

# ====================================================
# Funktionsexport
# ====================================================

use base qw(Exporter);
@EXPORT = qw(encoded_body answer_field message_field);

################################
# sub encoded_body
#
# Nachrichtentext in gueltiges
# HTML konvertieren
################################

sub encoded_body ($;$) {
  my $posting = ${+shift};
  my $params = shift;

  $posting =~ s/[ \t]$//gm;        # Whitespaces am Zeilenende entfernen
  $posting =~s /\s+$//;            # Whitespaces am Stringende entfernen
  $posting = ${plain (\$posting)}; # Sonderzeichen maskieren

  # Quotingzeichen normalisieren (\177)
  my $quote = plain($params -> {quoteChars});
  my $qquote = quotemeta $quote;
  my $len = length ($quote);
  $posting =~ s!^((?:$qquote)+)(.*)$!"\177" x (length($1)/$len) .$2!gem if (length ($qquote));

  # Multine
  $posting = ${multiline (\$posting)};

  # normaler Link
  $posting =~ s{\[link:\s*
               ((?:ftp://                          # hier beginnt $1
               |   https?://
               |   about:
               |   view-source:
               |   gopher://
               |   mailto:
               |   news:
               |   nntp://
               |   telnet://
               |   wais://
               |   prospero://
               |   \.\.?/                          # relativ auf dem server
               |   /                               # absolut auf dem server
               |   (?:[a-zA-Z.\d]+)?\??            # im forum
               )   [^\s<'()\[\]]+                  # auf jeden Fall kein \s und kein ] etc.
               )                                   # hier ist $1 zuende
               \s*(?:\]|(\s|&(?!amp;)|\(|\)|<br>)) # der Begrenzer (\s, ] oder Zeilenende)
              }
              {<a href="$1">$1</a>$2}gix;          # und der Link

  # javascript-links extra
  my $klammer1='\((?:[^)])*\)';
  my $klammer2="\\((?:$klammer1|(?:[^)])*)\\)";
  my $klammer3="\\((?:$klammer2|(?:[^)])*)\\)";
  my $klammer4="\\((?:$klammer3|(?:[^)])*)\\)";

  $posting =~ s{\[link:\s*
               (javascript:                        # hier beginnt $1
               (?:
                 $klammer4                         # Klammern bis Verschachtelungstiefe 4 (sollte reichen?)
               | '[^\'\\]*(?:\\.[^\'\\]*)*'        # mit ' quotierter String, J.F. sei gedankt
                                                   # im String sind Escapes zugelassen (also auch \')
                                                   # damit werden (korrekt gesetzte) Javascript-Links moeglich
               | [^\s<()'\]]+)+                    # auf jeden Fall kein \s und kein ] (ausser im String)
               )                                   # hier ist $1 zuende
               \s*(?:\s|\]|(\(|\)|&(?!amp;)|<br>)) # der Begrenzer (\s, ] oder Zeilenende)
              }
              {<a href="$1">$1</a>$2}gix;          # und der Link

  # images
  $posting =~ s{\[image:\s*
               ((?:https?://
               |   \.\.?/                          # relativ auf dem server
               |   /                               # absolut auf dem server
               |   (?:[a-zA-Z.\d]+)?\??            # im forum
               )   [^\s<'()\[\]]+                  # auf jeden Fall kein \s und kein ] etc.
               )                                   # hier ist $1 zuende
               \s*(?:\]|(\s|\(|\)|&(?!amp;)|<br>)) # der Begrenzer (\s, ] oder Zeilenende)
              }
              {<img src="$1" border=0 alt="">$2}gix; # und das Bild

  # iframe
  $posting =~ s{\[iframe:\s*
               ((?:ftp://
               |   https?://
               |   about:
               |   view-source:
               |   gopher://
               |   mailto:
               |   news:
               |   nntp://
               |   telnet://
               |   wais://
               |   prospero://
               |   \.\.?/                          # relativ auf dem server
               |   /                               # absolut auf dem server
               |   [a-zA-Z\d]+(?:\.html?|/)        # im forum (koennen eh nur threads oder verweise
                                                   # auf tiefere verzeichnisse sein)
               )[^\s<'()\]]+                       # auf jeden Fall kein \s und kein ] etc. (s.o.)
               )                                   # hier ist $1 zuende
               \s*(?:\]|(\s|\(|\)|&(?!amp;)|<br>)) # der Begrenzer (\s, ] oder Zeilenende)
              }
              {<iframe src="$1" width="90%" height="90%"><a href="$1">$1</a></iframe>$2}gix;

  # [msg...]
  $params -> {messages} = {} unless (defined $params -> {messages});
  my %msg = %{$params -> {messages}};
  foreach (keys %msg) {
    $posting =~ s/\[msg:\s*$_(?:\s*\]|\s)/'<img src="'.$msg{$_} -> {src}.'" width='.$msg{$_}->{width}.' height='.$msg{$_}->{height}.' border=0 alt="'.plain($msg{$_}->{alt}).'">'/gei;}

  # Rueckgabe
  \$posting;
}

################################
# sub answer_field
#
# Antwort HTML einer Message
# erzeugen
################################

sub answer_field ($$) {
  my $posting = shift;
  my $params = shift;
  $params = {} unless (defined $params);

  # ================
  # Antwortfeld
  # ================
  my $area = $$posting;

  my $qchar = $params -> {quoteChars};

  $area =~ s/(?:^|(<br>))(?!<br>)/$1 || '' . "\177"/eg if ($params -> {quoteArea}); # Antwortfeld quoten?!
  $area =~ s/\177/$qchar/g; # normalisierte Quotes jedenfalls in Chars umsetzen

  # HTML-Zeug zurueckuebersetzen

  $params -> {messages} = {} unless (defined $params -> {messages}); # um Fehlermeldungen auszuschliessen...
  my %msg = map {($params -> {messages} -> {$_} -> {src} => $_)} keys %{$params -> {messages}};

  $area =~ s{<iframe\s+src="([^"]*)"[^>]+>.*?</iframe>|<img\s+src="([^"]*)"\s+width[^>]+>|<img src="([^"]*)"[^>]*>|<a href="([^"]*)">.*?</a>}
            {if    (defined $1) {"[iframe: $1]"}
             elsif (defined $2) {"[msg: $msg{$2}]"}
             elsif (defined $3) {"[image: $3]"}
             elsif (defined $4) {"[link: $4]"}}eg;
  $area =~ s/<br>/\n/g;
  $area =~ s/&(?:#160|nbsp);/ /g;

  # Rueckgabe
  \$area;
}

################################
# sub message_field
#
# HTML eines Postingtextes
# erzeugen
################################

sub message_field ($$) {
  my $posting = ${+shift};
  my $params = shift;
  $params = {} unless (defined $params);

  # ================
  # Postingtext
  # ================
  my $qchar = $params -> {quoteChars};

  if ($params -> {quoting}) {    # Quotes bekommen eine extra Klasse?
    # ueberfluessige Abstaende entfernen,
    # sie werden eh wieder auseinandergezogen...
    $posting =~ s/(\177(?:[^<]|<(?!br>))*<br>)<br>(?=\177)/$1/g;
    $posting =~ s/(\177(?:[^<]|<(?!br>))*<br>)<br>(?!\177)/$1/g;

    my ($last_level, $level, $line, $q, @new)=(-1,0);

    foreach $line (split (/<br>/,$posting)) { # Zeilenweise gucken,
      ($q) = ($line =~ /^(\177+)/g);          # wieviele
      $level = length ($q or '');             # Quotingchars am Anfang stehen
      if ($level != $last_level) {            # wenn sich was verandert...
                                              # ... dann TU ETWAS!

        if    ($last_level <= 0 and $level > 0) {$last_level = $level; $line='<br>'.$params -> {startCite} . $line}
        elsif ($level > 0) {$last_level = $level; $line=$params -> {endCite} . '<br>' . $params -> {startCite} . $line}
        elsif ($level == 0 and $last_level > 0) {$last_level = -1; $line = $params -> {endCite} . '<br>' . $line}}

      push @new,$line}

    $new[0] =~ s/^<br>//;
    $posting = (join '<br>',@new) . (($last_level > 0)?$params -> {endCite}:'');}

  $posting =~ s/\177/$qchar/g; # normalisierte Quotes in Chars umsetzen

  # Rueckgabe
  \$posting;
}


# ====================================================
# Modulinitialisierung
# ====================================================

# making require happy
1;

# ====================================================
# end of Encode::Posting
# ====================================================