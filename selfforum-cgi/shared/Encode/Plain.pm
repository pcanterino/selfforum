package Encode::Plain;

################################################################################
#                                                                              #
# File:        shared/Encode/Plain.pm                                          #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>, 2001-04-12                          #
#                                                                              #
# Description: Encode text for HTML Output (entities, spaces)                  #
#                                                                              #
################################################################################

use strict;
use vars qw(
  @EXPORT
  %sonder
  %unimap
  $utf8
  $v56
);

$v56 = eval {local $SIG{__DIE__}; require 5.6.0;};

################################################################################
#
# Export
#
use base qw(Exporter);
@EXPORT = qw(plain multiline toUTF8);

### sub myunpack ###############################################################
#
# if perl version < 5.6 use myunpack instead of unpack 'U' ;(
#
# Params: $string - UTF8-encoded string to unpack
#
# Return: Number - unpacked UTF8
#
sub myunpack ($) {
  return unless defined $_[0];

  my @c = map {ord} split // => shift;

  return ($c[0] & 31) << 6 | $c[1] & 63
    if (
      @c == 2
      and ($c[0] & 224) == 192
      and ($c[1] & 192) == 128
    );

  return ($c[0] & 15) << 12 | ($c[1] & 63) << 6 | $c[2] && 63
    if (
      @c == 3
      and ($c[0] & 240) == 224
      and ($c[1] & 192) == 128
      and ($c[2] & 192) == 128
    );

  return;
}

### sub plain ##################################################################
#
# encode characters of plain text into entities for HTML output
# (includes < > " &)
# (excludes space problem)
#
# Params: $old - String (or scalar reference) to encode
#         $ref - (optional) (hash reference) Options
#                (-amp -except -utf8)
#
# Return: encoded string (or scalar reference)
#
sub plain ($;$) {
  my ($old, $ref) = @_;
  my $exreg;

  return unless (defined $old);

  my $new = ref ($old) ? $$old : $old;
  $ref = $ref || {};
  $new ='' unless (defined $new);

  my $unicode = defined ($ref -> {-utf8})
    ? $ref -> {-utf8}
    : $utf8;

  # Exceptions
  #
  my $except = exists($ref->{-except});
  if ($except) {

    if (ref ($ref -> {-except})) {
      # turn list into a regex
      #
      $exreg = join '|' => map {quotemeta $_} @{$ref -> {-except}};
    }
    else {
      # quote regex delimiters
      #
      $exreg = $ref -> {-except};
      $exreg =~ s|/|\\/|g;
    }
  }

  # encode the &-character
  #
  if (lc($ref->{-amp}) eq 'soft') {

    if ($except) {
      $new=~s/($exreg)|(?:\&(?!(?:#[Xx][\da-fA-F]+|#\d+|[a-zA-Z]+);))/defined($1)?$1:'&amp;'/eg;
    }
    else {
      $new=~s/\&(?!(?:#[Xx][\da-fA-F]+|#\d+|[a-zA-Z]+);)/&amp;/g;
    }
  }
  elsif (lc($ref->{-amp}) ne 'no') {

    if ($except) {
      $new=~s/($exreg)|\&/defined($1)?$1:'&amp;'/eg;
    }
    else {
      $new=~s/\&/&amp;/g;
    }
  }

  # further characters
  #
  if ($except) {
    $new =~ s/($exreg)|</defined($1)?$1:'&lt;'/eg;
    $new =~ s/($exreg)|>/defined($1)?$1:'&gt;'/eg;
    $new =~ s/($exreg)|\|/defined($1)?$1:'&#124;'/eg;
    $new =~ s/($exreg)|"/defined($1)?$1:'&quot;'/eg;

    # the big hash
    #
    if ($unicode) {
      my $x;
      if ($v56) {
        $new =~ s/($exreg)|([\300-\337][\200-\277]|[\340-\357][\200-\277][\200-\277])/
          defined($1)
            ? $1
            : ( exists($unimap{$x = unpack('U',$2)})
                ? $unimap{$x}
                : "&#$x;"
              )
          /eg;
      }
      else {
        $new =~ s/($exreg)|([\300-\337][\200-\277]|[\340-\357][\200-\277][\200-\277])/
          defined($1)
            ? $1
            : ( exists($unimap{$x = myunpack($2)})
                ? $unimap{$x}
                : "&#$x;"
              )
          /eg;
      }
    }
    $new =~ s/($exreg)|([\177-\377])/defined($1)?$1:$sonder{$2}/eg;
  }
  else {
    # no exceptions
    #
    $new =~ s/</&lt;/g;
    $new =~ s/>/&gt;/g;
    $new =~ s/\|/&#124;/g;
    $new =~ s/"/&quot;/g;

    # the big hash
    #
    if ($unicode) {
      my $x;
      if ($v56) {
        $new =~ s/([\300-\337][\200-\277]|[\340-\357][\200-\277][\200-\277])/
          exists($unimap{$x = unpack('U',$1)})
            ? $unimap{$x}
            : "&#$x;"
          /eg;
      }
      else {
        $new =~ s/([\300-\337][\200-\277]|[\340-\357][\200-\277][\200-\277])/
          exists($unimap{$x = myunpack($1)})
            ? $unimap{$x}
            : "&#$x;"
          /eg;
      }
    }
    $new =~ s/([\177-\377])/$sonder{$1}/g;
  }

  # characters < 32, but whitespaces
  #
  $new=~s/([^\041-\377\000\s])/
    '&#' . ord($1) . ';'
    /eg;
  $new=~s/\000/ /g;

  # return
  #
  ref $old
    ? \$new
    : $new;
}

### sub multiline ##############################################################
#
# solve the space problem
#
# Params: $old - String (or scalar reference): text to encode
#
# Return: scalar reference: encoded string
#
sub multiline ($) {
  my $old = shift;
  my $string=(ref ($old))
    ? $$old
    : $old;

  $string='' unless (defined $string);

  # normalize newlines
  #
  $string=~s/\015\012|\015|\012/\n/g;

  # turn \n into <br>
  #
  $string=~s/\n/<br>/g;

  # more than 1 space => &nbsp;
  #
  $string=~s/(\s\s+)/('&nbsp;' x (length($1)-1)) . ' '/eg;

  # Single Spaces after <br> => &nbsp;
  # (save ascii arts ;)
  #
  $string=~s/(?:^|(<br>))\s/($1?$1:'').'&nbsp;'/eg;

  # return
  #
  \$string;
}

### sub toUTF8 #################################################################
#
#  map ISO-8859-1 to UTF8
#
# Params: String or scalar reference: string to map
#
# Return: String or scalar reference: mapped string
#
sub toUTF8 ($) {
  my $ref = shift;
  my $string = ref($ref)
    ? $$ref
    : $ref;

  if ($v56) {
    no warnings 'utf8';
    $string =~ tr/\x80-\xff//CU;
  }
  else {
    $string =~ s
      {([\x80-\xff])}
      { chr((ord ($1) >> 6) | 192)
       .chr((ord ($1) & 191))
      }eg;
  }

  ref($ref)
    ? \$string
    : $string;
}

################################################################################
#
# package init
#
BEGIN {
  $utf8 = 0;

  # Latin 1 + guessed
  #
  %sonder=(
    "\177" => '&#127;',
    "\200" => '&#8364;',
    "\201" => '&uuml;',
    "\202" => '&#8218;',
    "\203" => '&#402;',
    "\204" => '&#8222;',
    "\205" => '&#8230;',
    "\206" => '&#8224;',
    "\207" => '&#8225;',
    "\210" => '&#710;',
    "\211" => '&#8240;',
    "\212" => '&#352;',
    "\213" => '&#8249;',
    "\214" => '&#338;',
    "\215" => '&igrave;',
    "\216" => '&#381;',
    "\217" => '&Aring;',
    "\220" => '&uuml;',
    "\221" => "'",
    "\222" => "'",
    "\223" => '&#8220;',
    "\224" => '&#8220;',
    "\225" => '&#8226;',
    "\226" => '-',
    "\227" => '-',
    "\230" => '&#732;',
    "\231" => '&#8482;',
    "\232" => '&#353;',
    "\233" => '&#8250;',
    "\234" => '&#339;',
    "\235" => '&#216;',
    "\236" => '&#215;',
    "\237" => '&#376;',
    "\240" => '&nbsp;',
    "\241" => '&#161;',
    "\242" => '&#162;',
    "\243" => '&pound;',
    "\244" => '&#164;',
    "\245" => '&yen;',
    "\246" => '&#166;',
    "\247" => '&sect;',
    "\250" => '&#168;',
    "\251" => '&copy;',
    "\252" => '&#170;',
    "\253" => '&laquo;',
    "\254" => '&#172;',
    "\255" => '-',
    "\256" => '&reg;',
    "\257" => '&szlig;',
    "\260" => '&#176;',
    "\261" => '&#177;',
    "\262" => '&#178;',
    "\263" => '&#179;',
    "\264" => '&acute;',
    "\265" => '&#181;',
    "\266" => '&#182;',
    "\267" => '&#183;',
    "\270" => '&cedil;',
    "\271" => '&sup1;',
    "\272" => '&#186;',
    "\273" => '&raquo;',
    "\274" => '&#188;',
    "\275" => '&#189;',
    "\276" => '&#190;',
    "\277" => '&#191;',
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
    "\320" => '&ETH;',
    "\321" => '&Ntilde;',
    "\322" => '&Ograve;',
    "\323" => '&Oacute;',
    "\324" => '&Ocirc;',
    "\325" => '&Otilde;',
    "\326" => '&Ouml;',
    "\327" => '&#215;',
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
    "\377" => '&yuml;'
  );

  # Unicode-Mapping
  %unimap=(
    128 => '&#8364;',
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
    255 => '&yuml;'
  );
}

# keeping require happy
1;

#
#
### end of Encode::Plain #######################################################