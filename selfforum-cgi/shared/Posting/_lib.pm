# Posting/_lib.pm

# ====================================================
# Autor: n.d.p. / 2001-01-07
# lm   : n.d.p. / 2001-02-25
# ====================================================
# Funktion:
#    * Schnittstellen fuer den Zugriff auf Messages
#    * Zeitdarstellung
# ====================================================

use strict;

package Posting::_lib;

use vars qw(@EXPORT_OK);
use base qw(Exporter);

use Encode::Plain; $Encode::Plain::utf8 = 1;

use XML::DOM;

# ====================================================
# Funktionsexport
# ====================================================

@EXPORT_OK = qw(get_message_header get_message_body get_message_node parse_single_thread
                hr_time short_hr_time long_hr_time
                get_all_threads
                create_forum_xml_string
                save_file);

# ====================================================
# Zugriff uebers DOM
# ====================================================

###########################
# sub get_message_header
#
# Messageheader auslesen
###########################

sub get_message_header ($) {
  my $node = shift;
  my %conf;

  my $header    = $node   -> getElementsByTagName ('Header', 0) -> item (0);
    my $author  = $header -> getElementsByTagName ('Author', 0) -> item (0);
      my $name  = $author -> getElementsByTagName ('Name', 0) -> item (0);
      my $email = $author -> getElementsByTagName ('Email', 0) -> item (0);
      my $home  = $author -> getElementsByTagName ('HomepageUrl', 0) -> item (0);
      my $image = $author -> getElementsByTagName ('ImageUrl', 0) -> item (0);
    my $cat     = $header -> getElementsByTagName ('Category', 0) -> item (0);
    my $subject = $header -> getElementsByTagName ('Subject', 0) -> item (0);
    my $date    = $header -> getElementsByTagName ('Date', 0) -> item (0);

    %conf = (name     => ($name    -> hasChildNodes)?$name    -> getFirstChild -> getData:undef,
             category => ($cat     -> hasChildNodes)?$cat     -> getFirstChild -> getData:undef,
             subject  => ($subject -> hasChildNodes)?$subject -> getFirstChild -> getData:undef,
             email    => (defined ($email) and $email -> hasChildNodes)?$email -> getFirstChild -> getData:undef,
             home     => (defined ($home)  and $home  -> hasChildNodes)?$home  -> getFirstChild -> getData:undef,
             image    => (defined ($image) and $image -> hasChildNodes)?$image -> getFirstChild -> getData:undef,
             time     => $date -> getAttribute ('longSec'));
  \%conf;
}

###########################
# sub get_message_header
#
# Messagebody auslesen
###########################

sub get_message_body ($$)
{
  my ($xml, $mid) = @_;
  my $body;

  foreach ($xml -> getElementsByTagName ('ContentList', 1) -> item (0) -> getElementsByTagName ('MessageContent', 0))
  {
    if ($_ -> getAttribute ('mid') eq $mid)
    {
      $body = ($_ -> hasChildNodes)?$_ -> getFirstChild -> getData:'';
      last;
    }
  }

  \$body;
}

###########################
# sub get_message_header
#
# Messagenode bestimmen
###########################

sub get_message_node ($$$) {
  my ($xml,$tid,$mid) = @_;
  my ($mnode,$tnode);

  for ( $xml -> getElementsByTagName ('Thread')) {
    if ($_ -> getAttribute ('id') eq $tid) {
      $tnode = $_;
      for ($tnode -> getElementsByTagName ('Message')) {
        if ($_ -> getAttribute ('id') eq $mid) {
          $mnode = $_;
          last;}}
      last;}}

  wantarray?($mnode, $tnode):$mnode;
}

###########################
# sub parse_single_thread
#
# einzelne Threaddatei
# parsen
###########################

sub parse_single_thread ($$;$) {
  my ($tnode, $deleted, $sorted) = @_;
  my ($header, @msg, %mno);

  for ($tnode -> getElementsByTagName ('Message')) {
    $header = get_message_header ($_);

    push @msg,{mid     => ($_ -> getAttribute ('id') =~ /(\d+)/)[0],
               ip      => $_ -> getAttribute ('ip'),
               kids    => [$_ -> getElementsByTagName ('Message', 0)],
               answers => $_ -> getElementsByTagName ('Message') -> getLength,
               deleted => ($_ -> getAttribute ('flag') eq 'deleted')?1:0,
               name    => plain($header -> {name}),
               cat     => plain($header -> {category} or ''),
               subject => plain($header -> {subject}),
               time    => plain($header -> {time})};
    $mno{$_} = $#msg;}

  # Eintraege ergaenzen und korrigieren
  my $level;
  $msg[0] -> {level} = 0;
  for (@msg) {
    $level = $_ -> {level} + 1;
    @{$_ -> {kids}} = map {$msg[$mno{$_}] -> {level} = $level; $mno{$_}} @{$_ -> {kids}};}

  # ============
  # Sortieren und bei Bedarf
  # geloeschte Messages entfernen

  my $smsg = sort_thread (\@msg, $sorted);
  delete_messages ($smsg) unless ($deleted);

  $smsg;
}

###########################
# sub create_message_xml
#
# Message-XML-String
# erzeugen
###########################

sub create_message_xml ($$$) {
  my ($xml, $msges, $num) = @_;

  my $msg = $msges -> [$num];

  my $message = $xml -> createElement ('Message');
  $message -> setAttribute ('id', 'm'.$msg -> {mid});
  $message -> setAttribute ('flag', 'deleted') if ($msg -> {deleted});

  # Header erzeugen
  my $header   = $xml -> createElement ('Header');

  # alles inside of 'Header'
  my $author   = $xml -> createElement ('Author');

  my $name     = $xml -> createElement ('Name');
  $name -> addText (toUTF8($msg -> {name}));

  my $email    = $xml -> createElement ('Email');

  my $category = $xml -> createElement ('Category');
  $category -> addText (toUTF8($msg -> {cat}));

  my $subject  = $xml -> createElement ('Subject');
  $subject -> addText (toUTF8($msg -> {subject}));

  my $date     = $xml -> createElement ('Date');
  $date -> setAttribute ('longSec', $msg -> {time});

    $author -> appendChild ($name);
    $author -> appendChild ($email);
    $header -> appendChild ($author);
    $header -> appendChild ($category);
    $header -> appendChild ($subject);
    $header -> appendChild ($date);
  $message -> appendChild ($header);

  if ($msg -> {kids}) {
    for (@{$msg -> {kids}}) {
      $message -> appendChild (&create_message_xml ($xml, $msges, $_));
    }
  }

  $message;
}

# ====================================================
# XML-Parsen von Hand
# ====================================================

###########################
# sub sort_thread
#
# Messages eines
# Threads sortieren
###########################

sub sort_thread ($$) {
  my ($msg, $sorted) = @_;

  my ($z, %mhash) = (0);

  if ($sorted) {  # aelteste zuerst
    for (@$msg) {
      @$msg[@{$_ -> {kids}}] = sort {$a -> {mid} <=> $b -> {mid}} @$msg[@{$_ -> {kids}}] if (@{$_ -> {kids}} > 1);
      $mhash{$_ -> {mid}} = [@$msg[@{$_ -> {kids}}]];}}

  else {          # juengste zuerst
    for (@$msg) {
      @$msg[@{$_ -> {kids}}] = sort {$b -> {mid} <=> $a -> {mid}} @$msg[@{$_ -> {kids}}] if (@{$_ -> {kids}} > 1);
      $mhash{$_ -> {mid}} = [@$msg[@{$_ -> {kids}}]];}}

  # Kinder wieder richtig einsortieren
  my @smsg = ($msg -> [0]);
  for (@smsg) {
    ++$z;
    splice @smsg,$z,0,@{$mhash{$_ -> {mid}}} if ($_ -> {answers});
    delete $_ -> {kids};}

  \@smsg;
}

###########################
# sub delete_messages
#
# geoeschte Nachrichten
# herausfiltern
###########################

sub delete_messages ($) {
  my $smsg = shift;

  my ($z, $oldlevel, @path) = (0,0,0);

  for (@$smsg) {
    if ($_ -> {deleted}) {
      my $n = $_ -> {answers}+1;
      for (@path) {$smsg -> [$_] -> {answers} -= $n;}
      splice @$smsg,$z,$n;}

    else {
      if ($_ -> {level} > $oldlevel) {
        push @path,$z;
        $oldlevel = $_ -> {level};}

      elsif ($_ -> {level} < $oldlevel) {
        splice @path,$_ -> {level}-$oldlevel;
        $oldlevel = $_ -> {level};}

      else { $path[-1] = $z; }

      $z++;}}

  return;
}

###########################
# sub get_all_threads
#
# Hauptdatei laden und
# parsen
###########################

sub get_all_threads ($$;$) {
  my ($file, $deleted, $sorted) = @_;
  my ($last_thread, $last_message, @unids, %threads);
  local *FILE;

  open FILE, $file or return undef;
  my $xml = join '', <FILE>;
  close(FILE) or return undef;

  if (wantarray) {
    ($last_thread)  = map {/(\d+)/} $xml =~ /<Forum.+?lastThread="([^"]+)"[^>]*>/;
    ($last_message) = map {/(\d+)/} $xml =~ /<Forum.+?lastMessage="([^"]+)"[^>]*>/;}

  my $reg_msg = qr~(?:</Message>
                     |<Message\s+id="m(\d+)"\s+unid="([^"]*)"(?:\s+flag="([^"]*)")?[^>]*>\s*
                      <Header>[^<]*(?:<(?!Name>)[^<]*)*
                        <Name>([^<]+)</Name>[^<]*(?:<(?!Category>)[^<]*)*
                        <Category>([^<]*)</Category>\s*
                        <Subject>([^<]+)</Subject>\s*
                        <Date\s+longSec="(\d+)"[^>]*>\s*
                      </Header>\s*(?:(<)/Message>|(?=(<)Message\s*)))~sx;

  while ($xml =~ /<Thread id="t(\d+)">([^<]*(?:<(?!\/Thread>)[^<]*)*)<\/Thread>/g) {

    my ($tid, $thread) = ($1, $2);
    my ($level, $cmno, @msg, @stack) = (0);

    while ($thread =~ m;$reg_msg;g) {

      if (defined($9)) {
        push @stack,$cmno if (defined $cmno);
        push @msg, {};

        if (defined $cmno) {
          push @{$msg[$cmno] -> {kids}}  => $#msg;
          push @{$msg[$cmno] -> {unids}} => $2;}
        else {
          push @unids => $2;}

        for (@stack) {$msg[$_] -> {answers}++}

        $cmno=$#msg;

       ($msg[-1] -> {mid},
        $msg[-1] -> {unid},
        $msg[-1] -> {name},
        $msg[-1] -> {cat},
        $msg[-1] -> {subject},
        $msg[-1] -> {time})     = ($1, $2, $4, $5, $6, $7);

        $msg[-1] -> {deleted} = ($3 eq 'deleted')?1:undef;

        $msg[-1] -> {name} =~ s/&amp;/&/g;
        $msg[-1] -> {cat} =~ s/&amp;/&/g;
        $msg[-1] -> {subject} =~ s/&amp;/&/g;

        $msg[-1] -> {unids} = [];
        $msg[-1] -> {kids} = [];
        $msg[-1] -> {answers} = 0;
        $msg[-1] -> {level} = $level++;}

      elsif (defined ($8)) {
        push @msg, {};

        if (defined $cmno) {
          push @{$msg[$cmno] -> {kids}}  => $#msg;
          push @{$msg[$cmno] -> {unids}} => $2;
          $msg[$cmno] -> {answers}++;}
        else {
          push @unids => $2;}

        for (@stack) {$msg[$_] -> {answers}++}

       ($msg[-1] -> {mid},
        $msg[-1] -> {unid},
        $msg[-1] -> {name},
        $msg[-1] -> {cat},
        $msg[-1] -> {subject},
        $msg[-1] -> {time})     = ($1, $2, $4, $5, $6, $7);

        $msg[-1] -> {deleted} = ($3 eq 'deleted')?1:undef;

        $msg[-1] -> {name} =~ s/&amp;/&/g;
        $msg[-1] -> {cat} =~ s/&amp;/&/g;
        $msg[-1] -> {subject} =~ s/&amp;/&/g;

        $msg[-1] -> {level} = $level;
        $msg[-1] -> {unids} = [];
        $msg[-1] -> {kids} = [];
        $msg[-1] -> {answers} = 0;}

      else {
        $cmno = pop @stack; $level--;}}

  # ============
  # Sortieren und bei Bedarf
  # geloeschte Messages entfernen

    my $smsg = sort_thread (\@msg, $sorted);
    delete_messages ($smsg) unless ($deleted);

    $threads{$tid} = $smsg if (@$smsg);
  }

  wantarray?(\%threads, $last_thread, $last_message, \@unids): \%threads;
}

###########################
# sub create_forum_xml_string
#
# Forumshauptdatei erzeugen
###########################

sub create_forum_xml_string ($$) {
  my ($threads, $param) = @_;
  my ($level, $thread, $msg);

  my $xml = '<?xml version="1.0" encoding="UTF-8"?>'."\n"
           .'<!DOCTYPE Forum SYSTEM "'.$param -> {dtd}.'">'."\n"
           .'<Forum lastMessage="'.$param -> {lastMessage}.'" lastThread="'.$param -> {lastThread}.'">';

  foreach $thread (sort {$b <=> $a} keys %$threads) {
    $xml .= '<Thread id="t'.$thread.'">';
    $level = -1;

    foreach $msg (@{$threads -> {$thread}}) {
      $xml .= '</Message>' x ($level - $msg -> {level} + 1) if ($msg -> {level} <= $level);
      $level = $msg -> {level};
      $xml .= '<Message id="m'.$msg -> {mid}.'"'
                  .' unid="'.$msg -> {unid}.'"'
                  .(($msg -> {deleted})?' flag="deleted"':'')
                  .'>'
             .'<Header>'
             .'<Author>'
             .'<Name>'
                  .plain($msg -> {name})
                  .'</Name>'
             .'<Email></Email>'
             .'</Author>'
             .'<Category>'
                  .((length $msg -> {cat})?plain($msg -> {cat}):'')
                  .'</Category>'
             .'<Subject>'
                  .plain($msg -> {subject})
                  .'</Subject>'
             .'<Date longSec="'
                  .$msg -> {time}
                  .'"/>'
             .'</Header>';}

    $xml .= '</Message>' x ($level + 1);
    $xml .= '</Thread>';}

  $xml.='</Forum>';

  \$xml;
}

###########################
# sub save_file
#
# Datei speichern
###########################

sub save_file ($$) {
  my ($filename,$content) = @_;
  local *FILE;

  open FILE,">$filename.temp" or return;

  unless (print FILE $$content) {
    close FILE;
    return;};

  close FILE or return;

  rename "$filename.temp", $filename or return;

  1;
}

# ====================================================
# Zeitdarstellung
# ====================================================

###########################
# sub hr_time
#     02. Januar 2001, 12:02 Uhr
#
# sub short_hr_time
#     02. 01. 2001, 12:02 Uhr
#
# sub long_hr_time
#     Dienstag, 02. Januar 2001, 12:02:01 Uhr
#
# formatierte Zeitangabe
###########################

sub hr_time ($) {
  my @month = qw(Januar Februar M\303\244rz April Mail Juni Juli August September Oktober November Dezember);
                               # ^^^^^^^^ - UTF8 #

  my (undef, $min, $hour, $day, $mon, $year) = localtime ($_[0]);

  sprintf ('%02d. %s %04d, %02d:%02d Uhr', $day, $month[$mon], $year+1900, $hour, $min);
}

sub short_hr_time ($) {
  my (undef, $min, $hour, $day, $mon, $year) = localtime ($_[0]);

  sprintf ('%02d. %02d. %04d, %02d:%02d Uhr', $day, $mon+1, $year+1900, $hour, $min);
}

sub long_hr_time ($) {
  my @month = qw(Januar Februar M\303\244rz April Mail Juni Juli August September Oktober November Dezember);
                               # ^^^^^^^^ - UTF8 #

  my @wday  = qw(Sonntag Montag Dienstag Mittwoch Donnerstag Freitag Samstag);
  my ($sek, $min, $hour, $day, $mon, $year, $wday) = localtime ($_[0]);

  sprintf ('%s, %02d. %s %04d, %02d:%02d:%02d Uhr', $wday[$wday], $day, $month[$mon], $year+1900, $hour, $min, $sek);
}

# ====================================================
# Modulinitialisierung
# ====================================================

# making require happy
1;

# ====================================================
# end of Posting::_lib
# ====================================================
