# Mail.pm

##############################################
#                                            #
# Autor: n.d.p. nd@o3media.de                #
#                                            #
# Letze Aenderung: n.d.p. / 2001-01-03       #
#                                            #
# ========================================== #
#                                            #
# Funktion:                                  #
#      ganz simples Formatieren und Senden   #
#      einer Mail im text/plain, qp-Format   #
#                                            #
##############################################

use strict;

package Mail;

use vars qw($mailbox $mailprog @EXPORT);

use autouse 'CheckRFC' => qw(is_email($));

# ===================
# Funktionsexport
# ===================

use base qw(Exporter);
@EXPORT = qw(is_mail_address send_mail);

########################################
# EXPORT
# sub is_mail_address
#
# Funktion:
#      Ueberpruefen der Syntax einer
#      Email-Adresse
#
# Rueckgabe
#      true/false
########################################

sub is_mail_address ($) {
  return is_email $_[0];
}

########################################
# EXPORT
# sub send_mail
#
# Funktion:
#      Senden der Nachricht
#      ueber open-print-close
#      $Mail::mailprog enthaelt
#      den vollstaendigen string fuer
#      open, dass heisst, es kann
#      auch ein Dateiname sein.
#
# Rueckgabe:
#      true/false
########################################

sub send_mail {
  my $param=shift;
  local *MAIL;

  open MAIL,$mailprog or return 0;
    print MAIL &as_string ($param);
  close MAIL and return 1;

  # Hier muss irgendwas schiefgelaufen sein
  0;
}

##########################################
# PRIVAT
# sub as_string
#
# Funktion:
#      Bereitstellung der gesamten Mail
#      als String.
#
# Rueckgabe:
#      String
##########################################

sub as_string {
  my $param=shift;

  my $header=&header_as_string ($param);
  my $body=&body_as_string ($param);

  # Rueckgabe
  "$header\n$body\n";
}

##########################################
# PRIVAT
# sub body_as_string
#
# Funktion:
#      Bereitstellung des Bodys
#      als (qp-codierten) String.
#
# Rueckgabe:
#      String
##########################################

sub body_as_string {
  my $param=shift;

  &encode_qp($param->{body});
}

##########################################
# PRIVAT
# sub header_as_string
#
# Funktion:
#      Bereitstellung des Headers
#      als String.
#
# Rueckgabe:
#      String
##########################################

sub header_as_string {
  my $param=shift;

  my $string="Content-Disposition: inline\n";
     $string.="MIME-Version: 1.0\n";
     $string.="Content-Transfer-Encoding: quoted-printable\n";
     $string.="Content-Type: text/plain\n";
     $string.="Date: ".&rfc822_date(time)."\n";
     $string.="From: ".$param->{'from'}."\n";
     $string.=&get_list('To',$param->{'to'});
     $string.=&get_list('Cc',$param->{'cc'});
     $string.=&get_list('Bcc',$param->{'bcc'});
     $string.="Subject: ".encode_qp($param->{'subject'})."\n";

  # Rueckgabe
  $string;
}

#######################################
# PRIVAT
# sub encode_qp
#
# C&P aus dem Modul MIME::QuotedPrint
# Thanx for that
#######################################

sub encode_qp ($)
{
    my $res = shift;
    $res =~ s/([^ \t\n!-<>-~])/sprintf("=%02X", ord($1))/eg;  # rule #2,#3
    $res =~ s/([ \t]+)$/
      join('', map { sprintf("=%02X", ord($_)) }
                   split('', $1)
      )/egm;                        # rule #3 (encode whitespace at eol)

    # rule #5 (lines must be shorter than 76 chars, but we are not allowed
    # to break =XX escapes.  This makes things complicated :-( )
    my $brokenlines = "";
    $brokenlines .= "$1=\n"
        while $res =~ s/(.*?^[^\n]{73} (?:
                 [^=\n]{2} (?! [^=\n]{0,1} $) # 75 not followed by .?\n
                |[^=\n]    (?! [^=\n]{0,2} $) # 74 not followed by .?.?\n
                |          (?! [^=\n]{0,3} $) # 73 not followed by .?.?.?\n
            ))//xsm;

    "$brokenlines$res";
}

##############################################
# PRIVAT
# sub get_list
#
# Funktion:
#      Aufbereitung einer Liste oder eines
#      Strings fuer den Header (To, Cc, Bcc)
#
# Rueckgabe:
#      Ergebnis oder nichts
##############################################

sub get_list ($$) {
  my ($start,$list)=splice @_;

  return $start . ': ' . $list . "\n" if (defined $list and not ref $list and length $list);

  return $start . ': ' . join (', ',@$list) . "\n" if (ref $list);

  '';
}

##############################################
# PRIVAT
# sub rfc822_date
#
# Funktion:
#      Bereitstellung eines RFC-konformen
#      Datumstrings
#
# Rueckgabe:
#      Datumstring
##############################################

sub rfc822_date ($) {
  my ($sek, $min, $std, $mtag, $mon, $jahr, $wtag) = gmtime (+shift);

  sprintf ('%s, %02d %s %04d %02d:%02d:%02d GMT',
             (qw(Sun Mon Tue Wed Thu Fri Sat))[$wtag],
             $mtag,
             (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec))[$mon],
             $jahr+1900, $std, $min, $sek);
}

##############################################
# Modulinitialisierung
# BEGIN
#
# Funktion:
#      Bereitstellung des Regexps und des
#      Mailprogs
##############################################

BEGIN {
    # Standard-Mailprogramm

    # Dieser String wird so, wie er ist, an die open-Anweisung geschickt,
    # -t  = tainted(?),der Header (=alles bis zur ersten Leerzeile)
    #       wird nach To:, Cc: und evtl. Bcc: abgesucht.
    # -oi = damit wird verhindert, dass sendmail, ein Zeile, wo nur ein
    #       Punkt drinsteht, als Mailende erkennt( waere Standard ).
    # ===================================================================

    $mailprog = '|/usr/lib/sendmail -t -oi';
}

# keeping require happy
1;

#####################
# end of Mail
#####################