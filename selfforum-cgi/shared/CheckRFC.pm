package CheckRFC;

################################################################################
#                                                                              #
# File:        shared/CheckRFC.pm                                              #
#                                                                              #
# Authors:     Andre Malo       <nd@o3media.de>, 2001-03-30                    #
#                                                                              #
# Description: implement several string checks on RFC correctness              #
#                                                                              #
################################################################################

use strict;
use vars qw(%url $email @EXPORT);

use autouse 'Carp' => qw(croak);

################################################################################
#
# Export
#
use base qw(Exporter);
@EXPORT = qw(is_URL is_email);

### is_URL ($@) ################################################################
#
# check URL
#
# Params: $string  string to check
#         @schemes possible URL schemes in $string
#                  qw(http ftp news nntp telnet gopher wais mailto file prospero)
#                  if there's no scheme given, 'http' is default
#                  use ':ALL' (without quotes) for all schemes
#
# Return: Status code (Bool)
#
sub is_URL ($@) {
  my ($string, @schemes) = @_;
  @schemes = qw(http) unless (@schemes);
  @schemes = keys %url if (@schemes == 1 and $schemes[0] eq ':ALL');

  for (@schemes) {
    croak "unknown url scheme '$_'" unless exists $url{$_};
    return 1 if $string =~ /$url{$_}/;
  }

  # no match => return false
  return;
}

### is_email ($) ###############################################################
#
# check email (comments can be nested)
#
# Params: $string string to check
#
# Return: Status code (Bool)
#
sub is_email ($) {
  my $string = shift;

  # false if any non-ascii chars
  return if $string =~ /[\200-\377]/;

  # remove nested comments
  while ($string =~ s/\([^()]*\)//g) {};

  return ($string =~ /^$email$/);
}

### BEGIN # (1) ################################################################
#
# define regex for nearly RFC 822 email address
#
BEGIN {
  # Thanx to J. Friedl:

  my $esc        = '\\\\';
  my $Period      = '\.';
  my $space      = '\040';
  my $tab         = '\t';
  my $OpenBR     = '\[';
  my $CloseBR     = '\]';
  my $OpenParen  = '\(';
  my $CloseParen  = '\)';
  my $NonASCII   = '\x80-\xff';
  my $ctrl        = '\000-\037';
  my $CRlist     = '\n\015';
  my $qtext = qq/[^$esc$NonASCII$CRlist\"]/;
  my $dtext = qq/[^$esc$NonASCII$CRlist$OpenBR$CloseBR]/;
  my $quoted_pair = qq< $esc [^$NonASCII] >;
  my $ctext   = qq< [^$esc$NonASCII$CRlist()] >;
  my $Cnested = qq< $OpenParen $ctext* (?: $quoted_pair $ctext* )* $CloseParen >;
  my $comment = qq< $OpenParen $ctext* (?: (?: $quoted_pair | $Cnested ) $ctext* )* $CloseParen >;
  my $X = qq< [$space$tab]* (?: $comment [$space$tab]* )* >;
  my $atom_char   = qq/[^($space)<>\@,;:\".$esc$OpenBR$CloseBR$ctrl$NonASCII]/;
  my $atom = qq< $atom_char+ (?!$atom_char) >;
  my $quoted_str = qq< \" $qtext * (?: $quoted_pair $qtext * )* \" >;
  my $word = qq< (?: $atom | $quoted_str ) >;
  my $domain_ref  = $atom;
  my $domain_lit  = qq< $OpenBR (?: $dtext | $quoted_pair )* $CloseBR >;
  my $sub_domain  = qq< (?: $domain_ref | $domain_lit ) $X >;
  my $domain = qq< $sub_domain (?: $Period $X $sub_domain )* >;
  my $route = qq< \@ $X $domain (?: , $X \@ $X $domain )* : $X >;
  my $local_part = qq< $word $X (?: $Period $X $word $X )* >;
  my $addr_spec  = qq< $local_part \@ $X $domain >;
  my $route_addr = qq[ < $X (?: $route )? $addr_spec > ];
  my $phrase_ctrl = '\000-\010\012-\037';
  my $phrase_char = qq/[^()<>\@,;:\".$esc$OpenBR$CloseBR$NonASCII$phrase_ctrl]/;
  my $phrase = qq< $word $phrase_char * (?: (?: $comment | $quoted_str ) $phrase_char * )* >;
  $email = qq< $X (?: $addr_spec | $phrase  $route_addr ) >;
  $email = qr /$email/x;
}

### BEGIN # (2) ################################################################
#
# define regexes for URLs
#
BEGIN {
  # credits to an unknown(?) programmer ;)
  # modified by n.d.p.

  my $lowalpha       =  '(?:[a-z])';
  my $hialpha        =  '(?:[A-Z])';
  my $alpha          =  "(?:$lowalpha|$hialpha)";
  my $digit          =  '(?:\d)';
  my $safe           =  '(?:[$_.+-])';
  my $extra          =  '(?:[!*\'(),])';
  my $national       =  '(?:[{}|\\\\^~\[\]`])';
  my $punctuation    =  '(?:[<>#%"])';
  my $reserved       =  '(?:[;/?:@&=])';
  my $hex            =  '(?:[\dA-Fa-f])';
  my $escape         =  "(?:%$hex$hex)";
  my $unreserved     =  "(?:$alpha|$digit|$safe|$extra)";
  my $uchar          =  "(?:$unreserved|$escape)";
  my $xchar          =  "(?:$unreserved|$escape|$reserved)";
  my $digits         =  '(?:\d+)';
  my $alphadigit     =  "(?:$alpha|\\d)";

  # URL schemeparts for ip based protocols:
  my $urlpath        =  "(?:$xchar*)";
  my $user           =  "(?:(?:$uchar|[;?&=])*)";
  my $password       =  "(?:(?:$uchar|[;?&=])*)";
  my $port           =  '(?:[0-5]?\d\d?\d?\d?|6[0-4]\d\d\d|65[0-4]\d\d|655[0-2]\d|6553[0-5])';
  my $ip4part        =  '(?:[01]?\d\d?|2[0-4]\d|25[0-5])';
  my $hostnumber     =  '(?:(?!0+\.0+\.0+\.0+)'."$ip4part\\.$ip4part\\.$ip4part\\.$ip4part)";
  my $toplabel       =  "(?:(?:$alpha(?:$alphadigit|-)*$alphadigit)|$alpha)";
  my $domainlabel    =  "(?:(?:$alphadigit(?:$alphadigit|-)*$alphadigit)|$alphadigit)";
  my $hostname       =  "(?:(?:$domainlabel\\.)*$toplabel)";
  my $host           =  "(?:(?:$hostname)|(?:$hostnumber))";
  my $hostport       =  "(?:(?:$host)(?::$port)?)";
  my $login          =  "(?:(?:$user(?::$password)?\@)?$hostport)";
  my $ip_schemepart  =  "(?://$login(?:/$urlpath)?)";

  my $schemepart     =  "(?:$xchar*|$ip_schemepart)";
  my $scheme         =  "(?:(?:$lowalpha|$digit|[+.-])+)";

  # The predefined schemes:

  # FTP (see also RFC959)
  my $fsegment       =  "(?:(?:$uchar|[?:\@&=])*)";
  my $ftptype        =  "(?:[AIDaid])";
  my $fpath          =  "(?:$fsegment(?:/$fsegment)*)";
  my $ftpurl         =  "(?:ftp://$login(?:/$fpath(?:;type=$ftptype)?)?)";

  # FILE
  my $fileurl        =  "(?:file://(?:(?:$host)|localhost)?/$fpath)";

  # HTTP
  my $httpuchar      =  "(?:(?:$alpha|$digit|$safe|(?:[!*\',]))|$escape)";
  my $hsegment       =  "(?:(?:$httpuchar|[;:\@&=~])*)";
  my $search         =  "(?:(?:$httpuchar|[;:\@&=~])*)";
  my $hpath          =  "(?:$hsegment(?:/$hsegment)*)";
  my $httpurl        =  "(?:http://$hostport(?:/$hpath(?:\\?$search)?)?(?:#$xchar*)?)";

  # GOPHER (see also RFC1436)
  my $gopher_plus    =  "(?:$xchar*)";
  my $selector       =  "(?:$xchar*)";
  my $gtype          =  "(?:$xchar)";
  my $gopherurl      =  "(?:gopher://$hostport(?:/$gtype(?:$selector(?:%09$search(?:%09$gopher_plus)?)?)?)?)";

  # MAILTO (see also RFC822)
  my $encoded822addr =  "(?:$email)";
  my $mailtourl      =  "(?:mailto:$encoded822addr)";

  # NEWS (see also RFC1036)
  my $article        =  "(?:(?:$uchar|[;/?:&=])+\@$host)";
  my $group          =  "(?:$alpha(?:$alpha|$digit|[.+_-])*)";
  my $grouppart      =  "(?:$article|$group|\\*)";
  my $newsurl        =  "(?:news:$grouppart)";

  # NNTP (see also RFC977)
  my $nntpurl        =  "(?:nntp://$hostport/$group(?:/$digits)?)";

  # TELNET
  my $telneturl      =  "(?:telnet://$login(?:/)?)";

  # WAIS (see also RFC1625)
  my $wpath          =  "(?:$uchar*)";
  my $wtype          =  "(?:$uchar*)";
  my $database       =  "(?:$uchar*)";
  my $waisdoc        =  "(?:wais://$hostport/$database/$wtype/$wpath)";
  my $waisindex      =  "(?:wais://$hostport/$database\\?$search)";
  my $waisdatabase   =  "(?:wais://$hostport/$database)";
  my $waisurl        =  "(?:$waisdatabase|$waisindex|$waisdoc)";

  # PROSPERO
  my $fieldvalue     =  "(?:(?:$uchar|[?:\@&]))";
  my $fieldname      =  "(?:(?:$uchar|[?:\@&]))";
  my $fieldspec      =  "(?:;$fieldname=$fieldvalue)";
  my $psegment       =  "(?:(?:$uchar|[?:\@&=]))";
  my $ppath          =  "(?:$psegment(?:/$psegment)*)";
  my $prosperourl    =  "(?:prospero://$hostport/$ppath(?:$fieldspec)*)";

  %url = (
    http     => qr/^$httpurl$/,
    ftp      => qr/^$ftpurl$/,
    news     => qr/^$newsurl$/,
    nntp     => qr/^$nntpurl$/,
    telnet   => qr/^$telneturl$/,
    gopher   => qr/^$gopherurl$/,
    wais     => qr/^$waisurl$/,
    mailto   => qr/^$mailtourl$/,
    file     => qr/^$fileurl$/,
    prospero => qr/^$prosperourl$/
  );
}

# keeping require happy
1;

#
#
### end of CheckRFC ############################################################