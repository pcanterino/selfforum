# Encode/Plain.pm

# ====================================================
# Autor: n.d.p. / 2001-01-07
# lm   : n.d.p. / 2001-02-25
# ====================================================
# Funktion:
#      Codierung von non-ASCII-Zeichen fuer
#      HTML
# ====================================================

use strict;

package Encode::Plain;

require 5.6.0;

use vars qw(@EXPORT %sonder %unimap $utf8);

# ====================================================
# Funktionsexport
# ====================================================

use base qw(Exporter);
@EXPORT = qw(plain multiline toUTF8);

################################
# sub plain
#
# einfache Sonderzeichen ->
# Entity-Codierung
################################

sub plain ($;$) {
  my ($old,$ref)=@_;
  my $exreg;

  return \'' unless (defined $old);

  my $new=(ref ($old))?$$old:$old;;
  $ref=($ref or {});

  # Ausnahmen
  my $except=exists($ref->{-except});
  if ($except) {

    # Referenz, also Liste uebergeben -> umwandeln in Regex
    if (ref ($ref -> {-except})) {
      $exreg = join ('|',map {quotemeta $_} @{$ref -> {-except}});}

    # keine Referenz, also Regex angegeben
    else {
      $exreg = $ref -> {-except};
      $exreg =~ s/\//\\\//g;}}      # LTS :-)

  if (lc($ref->{-amp}) eq 'soft') {

    if ($except) {
      $new=~s/($exreg)|(?:\&(?!(?:#[Xx][\da-fA-F]+|#\d+|[a-zA-Z]+);))/(length($1))?$1:'&amp;'/eg;}

    else {
      $new=~s/\&(?!(?:#[Xx][\da-fA-F]+|#\d+|[a-zA-Z]+);)/&amp;/g;}}

  elsif (lc($ref->{-amp}) ne 'no') {

    if ($except) {
      $new=~s/($exreg)|\&/(length($1))?$1:'&amp;'/eg;}

    else {
      $new=~s/\&/&amp;/g;}}

    #  Weitere Zeichen
  if ($except) {
    $new =~ s/($exreg)|</(length($1))?$1:'&lt;'/eg;     # HTML ausschalten
    $new =~ s/($exreg)|>/(length($1))?$1:'&gt;'/eg;
    $new =~ s/($exreg)|\|/(length($1))?$1:'&#124;'/eg;  # nich wahr
    $new =~ s/($exreg)|"/(length($1))?$1:'&quot;'/eg;   # Diese Zeile wird den Bannerklickern
                                                        # zu schaffen machen, sowas aber auch...

    # Der grosse Hash
    if ($utf8 or $ref -> {-utf8}) {
      my $x;
      $new =~ s/($exreg)|([\300-\337][\200-\277]|[\340-\357][\200-\277][\200-\277])/
                length($1)?$1:(exists($unimap{$x = unpack('U',$2)})?$unimap{$x}:"&#$x;")/eg;}

    $new =~ s/($exreg)|([\177-\377])/(length($1))?$1:$sonder{$2}/eg;}

  else {
    $new =~ s/</&lt;/g;
    $new =~ s/>/&gt;/g;
    $new =~ s/\|/&#124;/g;
    $new =~ s/"/&quot;/g;

    # Der grosse Hash
    if ($utf8 or $ref -> {-utf8}) {
      my $x;
      $new =~ s/([\300-\337][\200-\277]|[\340-\357][\200-\277][\200-\277])/
                exists($unimap{$x = unpack('U',$1)})?$unimap{$x}:"&#$x;"/eg;}

    $new =~ s/([\177-\377])/$sonder{$1}/g;}

  # Zeichen <= 31
  $new=~s/([\001-\010\013\014\016-\037])/'&#'.ord($1).';'/eg;
  $new=~s/\000/ /g;

  # Rueckgabe
  ref($old)?\$new:$new;
}

################################
# sub multiline
#
# Whitespacecodierung
# fuer Leerzeilen
################################

sub multiline {
  my $old=shift;
  my $string=(ref ($old))?$$old:$old;

  # Zeilenumbrueche normalisieren
  $string=~s/\015\012|\015|\012/\n/g;

  # Zeilenumbrueche in <br> umwandeln
  $string=~s/\n/<br>/g;

  # mehr als ein aufeinanderfolgendes
  # Leerzeichen in feste Leerzeichen umwandeln
  $string=~s/(\s\s+)/('&nbsp;' x (length($1)-1)) . ' '/eg;

  # Leerzeichen nach einem <br> in feste
  # Spaces umwandeln
  $string=~s/(?:^|(<br>))\s/$1&nbsp;/g;

  # Rueckgabe
  \$string;
}

sub toUTF8 ($) {
  my $ref = shift;
  my $string = ref($ref)?$$ref:$ref;
  no warnings 'utf8';

  $string =~ tr/\x80-\xff//CU;

  ref($ref)?\$string:$string;
}

# ====================================================
# Modulinitialisierung
# ====================================================

BEGIN {
  $utf8 = 0;

  # Latin 1 + geraten
  %sonder=("\177" => '&#127;',    # Delete-Zeichen
           "\200" => '&#8364;',   # Euro-Zeichen
           "\201" => '&uuml;',    # ue - DOS-Zeichensatz
           "\202" => '&#8218;',   # einfaches Anfuehrungszeichen unten
           "\203" => '&#402;',    # forte
           "\204" => '&#8222;',   # doppelte Anfuehrungszeichen unten
           "\205" => '&#8230;',   # drei punkte
           "\206" => '&#8224;',   # dagger
           "\207" => '&#8225;',   # Dagger
           "\210" => '&#710;',    # circ
           "\211" => '&#8240;',   # Promille
           "\212" => '&#352;',    # so ein S mit Haken drueber :-)
           "\213" => '&#8249;',   # lsaquo
           "\214" => '&#338;',    # OE (so verhakelt - daenisch?) wer weiss das schon
           "\215" => '&igrave;',  # Codepage 850;
           "\216" => '&#381;',    # Z mit Haken drueber (Latin Extended B)
           "\217" => '&Aring;',   # Codepage 850 (Win)
           "\220" => '&uuml;',    # ue - Mac-Zeichensatz
           "\221" => "'",         # einfache Anfuehrungszeichen oben
           "\222" => "'",         # dito
           "\223" => '&#8220;',   # doppelte Anfuehrungszeichen oben
           "\224" => '&#8220;',   # dito
           "\225" => '&#8226;',   # Bullet
           "\226" => '-',         # Bindestrich
           "\227" => '-',         # dito
           "\230" => '&#732;',    # tilde...?
           "\231" => '&#8482;',   # Trade-Mark
           "\232" => '&#353;',    # kleines s mit Haken drueber
           "\233" => '&#8250;',   # rsaquo;
           "\234" => '&#339;',    # oe verhakelt
           "\235" => '&#216;',    # Codepage 850 (Win)
           "\236" => '&#215;',    # Codepage 850 (Win)
           "\237" => '&#376;',    # Y mit Punkten drueber
           "\240" => '&nbsp;',    # nbsp;
           "\241" => '&#161;',    # umgedrehtes !
           "\242" => '&#162;',    # cent-Zeichen
           "\243" => '&pound;',   # (engl.)Pfund-Zeichen
           "\244" => '&#164;',    # Waehrungszeichen
           "\245" => '&yen;',     # Yen halt :-)
           "\246" => '&#166;',    # eigentlich soll es wohl ein | sein .-)
           "\247" => '&sect;',    # Paragraph
           "\250" => '&#168;',    # zwei Punkte oben
           "\251" => '&copy;',    # (C)
           "\252" => '&#170;',    # hochgestelltes unterstrichenes a
           "\253" => '&laquo;',   # left-pointing double angle quotation mark (besser koennte ichs auch nicht beschreiben...)
           "\254" => '&#172;',    # Negationszeichen
           "\255" => '-',         # Bindestrich
           "\256" => '&reg;',     # (R)
           "\257" => '&szlig;',   # sz, was auch immer fuern Zeichensatz (DOS?)
           "\260" => '&#176;',    # Grad-Zeichen
           "\261" => '&#177;',    # Plusminus
           "\262" => '&#178;',    # hoch 2
           "\263" => '&#179;',    # hoch 3
           "\264" => '&acute;',   # Acute
           "\265" => '&#181;',    # my-Zeichen (griech)
           "\266" => '&#182;',    # Absatzzeichen
           "\267" => '&#183;',    # Mal-Zeichen
           "\270" => '&cedil;',
           "\271" => '&sup1;',    # hoch 1
           "\272" => '&#186;',    # masculine ordinal indicator (spanish)
           "\273" => '&raquo;',   # right-pointing double angle quotation mark
           "\274" => '&#188;',    # 1/4
           "\275" => '&#189;',    # 1/2
           "\276" => '&#190;',    # 3/4
           "\277" => '&#191;',    # umgedrehtes ?
           "\300" => '&Agrave;',
           "\301" => '&Aacute;',
           "\302" => '&Acirc;',
           "\303" => '&Atilde;',
           "\304" => '&Auml;',
           "\305" => '&Aring;',
           "\306" => '&AElig;',
           "\307" => '&Ccedil;',
           "\310" => '&Egrave;',
           "\311" => '&Eacute;',
           "\312" => '&Ecirc;',
           "\313" => '&Euml;',
           "\314" => '&Igrave;',
           "\315" => '&Iacute;',
           "\316" => '&Icirc;',
           "\317" => '&Iuml;',
           "\320" => '&ETH;',     # keine Ahnung, was das wohl sein soll, auf jeden Fall was islaendisches...
           "\321" => '&Ntilde;',
           "\322" => '&Ograve;',
           "\323" => '&Oacute;',
           "\324" => '&Ocirc;',
           "\325" => '&Otilde;',
           "\326" => '&Ouml;',
           "\327" => '&#215;',    # eigentlich &times; funzt afaik aber nicht aufm Mac (ob das hier funktioniert, weiss ich nicht)
           "\330" => '&Oslash;',
           "\331" => '&Ugrave;',
           "\332" => '&Uacute;',
           "\333" => '&Ucirc;',
           "\334" => '&Uuml;',
           "\335" => '&Yacute;',
           "\336" => '&THORN;',
           "\337" => '&szlig;',
           "\340" => '&agrave;',
           "\341" => '&aacute;',
           "\342" => '&acirc;',
           "\343" => '&atilde;',
           "\344" => '&auml;',
           "\345" => '&aring;',
           "\346" => '&aelig;',
           "\347" => '&ccedil;',
           "\350" => '&egrave;',
           "\351" => '&eacute;',
           "\352" => '&ecirc;',
           "\353" => '&euml;',
           "\354" => '&igrave;',
           "\355" => '&iacute;',
           "\356" => '&icirc;',
           "\357" => '&iuml;',
           "\360" => '&eth;',
           "\361" => '&ntilde;',
           "\362" => '&ograve;',
           "\363" => '&oacute;',
           "\364" => '&ocirc;',
           "\365" => '&otilde;',
           "\366" => '&ouml;',
           "\367" => '&divide;',
           "\370" => '&oslash;',
           "\371" => '&ugrave;',
           "\372" => '&uacute;',
           "\373" => '&ucirc;',
           "\374" => '&uuml;',
           "\375" => '&yacute;',
           "\376" => '&thorn;',
           "\377" => '&yuml;');

  # Unicode-Mapping
  %unimap=(128 => '&#8364;',
           129 => '&uuml;',
           130 => '&#8218;',
           131 => '&#402;',
           132 => '&#8222;',
           133 => '&#8230;',
           134 => '&#8224;',
           135 => '&#8225;',
           136 => '&#710;',
           137 => '&#8240;',
           138 => '&#352;',
           139 => '&#8249;',
           140 => '&#338;',
           141 => '&igrave;',
           142 => '&#381;',
           143 => '&Aring;',
           144 => '&uuml;',
           145 => "'",
           146 => "'",
           147 => '&#8220;',
           148 => '&#8220;',
           149 => '&#8226;',
           150 => '-',
           151 => '-',
           152 => '&#732;',
           153 => '&#8482;',
           154 => '&#353;',
           155 => '&#8250;',
           156 => '&#339;',
           157 => '&#216;',
           158 => '&#215;',
           159 => '&#376;',
           160 => '&nbsp;',
           163 => '&pound;',
           165 => '&yen;',
           167 => '&sect;',
           169 => '&copy;',
           171 => '&laquo;',
           173 => '-',
           174 => '&reg;',
           175 => '&szlig;',
           180 => '&acute;',
           184 => '&cedil;',
           185 => '&sup1;',
           187 => '&raquo;',
           192 => '&Agrave;',
           193 => '&Aacute;',
           194 => '&Acirc;',
           195 => '&Atilde;',
           196 => '&Auml;',
           197 => '&Aring;',
           198 => '&AElig;',
           199 => '&Ccedil;',
           200 => '&Egrave;',
           201 => '&Eacute;',
           202 => '&Ecirc;',
           203 => '&Euml;',
           204 => '&Igrave;',
           205 => '&Iacute;',
           206 => '&Icirc;',
           207 => '&Iuml;',
           208 => '&ETH;',
           209 => '&Ntilde;',
           210 => '&Ograve;',
           211 => '&Oacute;',
           212 => '&Ocirc;',
           213 => '&Otilde;',
           214 => '&Ouml;',
           216 => '&Oslash;',
           217 => '&Ugrave;',
           218 => '&Uacute;',
           219 => '&Ucirc;',
           220 => '&Uuml;',
           221 => '&Yacute;',
           222 => '&THORN;',
           223 => '&szlig;',
           224 => '&agrave;',
           225 => '&aacute;',
           226 => '&acirc;',
           227 => '&atilde;',
           228 => '&auml;',
           229 => '&aring;',
           230 => '&aelig;',
           231 => '&ccedil;',
           232 => '&egrave;',
           233 => '&eacute;',
           234 => '&ecirc;',
           235 => '&euml;',
           236 => '&igrave;',
           237 => '&iacute;',
           238 => '&icirc;',
           239 => '&iuml;',
           240 => '&eth;',
           241 => '&ntilde;',
           242 => '&ograve;',
           243 => '&oacute;',
           244 => '&ocirc;',
           245 => '&otilde;',
           246 => '&ouml;',
           247 => '&divide;',
           248 => '&oslash;',
           249 => '&ugrave;',
           250 => '&uacute;',
           251 => '&ucirc;',
           252 => '&uuml;',
           253 => '&yacute;',
           254 => '&thorn;',
           255 => '&yuml;');
}

# making require happy
1;

# ====================================================
# end of Encode::Plain
# ====================================================