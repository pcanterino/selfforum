#!/usr/bin/perl

################################################################################
#                                                                              #
# File:        user/fo_posting.pl                                              #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>, 2001-01-25                          #
#                                                                              #
# Description: Accept new postings, display "Neue Nachricht" page              #
#                                                                              #
################################################################################

use strict;
use vars qw($Bin $Shared $Script %subhash $httpurl $flocked);

BEGIN {
  ($Bin)    = ($0 =~ /^(.*)\/.*$/)? $1 : '.';
  $Shared   = "$Bin/../shared";
  ($Script) = ($0 =~ /^.*\/(.*)$/)? $1 : $0;}

use CGI::Carp qw(fatalsToBrowser);

use lib "$Shared";
use Conf;
use Encode::Plain; $Encode::Plain::utf8 = 1;
use Encode::Posting;
use Id;
use Lock qw(:ALL);
use Mail;
use Posting::_lib qw(get_all_threads get_message_node get_message_header hr_time);
use Posting::Write;
use Template;
use Template::Posting;

use CGI qw(param header);
use XML::DOM;

print header (-type => 'text/html');

our $conf = read_script_conf ($Bin, $Shared, $Script);

our $show_posting = $conf -> {show} -> {Posting};
our $assign   = $show_posting -> {assign};
our $formmust = $show_posting -> {form} -> {must};
our $formdata = $show_posting -> {form} -> {data};
our $formact  = $show_posting -> {form} -> {action};
our $template = new Template $show_posting -> {templateFile};
our $pars = {};
our ($failed, %dparam, $threads, $last_thread, $last_message, $ftid, $fmid, $flocked);

sub forum_filename () {$conf -> {files} -> {forum};}
sub message_path () {$conf -> {files} -> {messagePath};}

################################

# Formfelder ausfuellen (Namen)
for (qw(posterBody uniqueID followUp quoteChar userID posterName posterEmail posterCategory posterSubject posterURL posterImage)) {
  $pars -> {$formdata -> {$_} -> {assign} -> {name}} = plain($formdata -> {$_} -> {name});}

my $checked = &check_param;

unless (exists ($subhash {$checked})) {
  &print_fatal ($assign -> {unknownError});}

else {
  unless ($checked eq 'newThread') {
    $checked = &check_reply_dupe() || $checked;}

  unless (exists ($subhash {$checked})) {
    &print_fatal ($assign -> {unknownError});}
  else {
    &{$subhash {$checked}};}

  if ($flocked) {
    violent_unlock_file (forum_filename) unless (write_unlock_file (forum_filename));}}

# ====================================================
# end of main / Funktionen
# ====================================================


### check_reply_dupe () ########################################################
#
# Reply moeglich? Doppelposting?
#
# Params: -none-
# Return: Dupe check result
#         'Dupe'  - Posting is a dupe
#         Nothing - ok.
#
sub check_reply_dupe () {
  my $stat;

  unless ($stat = write_lock_file (forum_filename)) {
    if ($stat == 0) {
      # ueberlastet oder so
      violent_unlock_file (forum_filename);
      return 'Occupied';
    } else {
      return 'masterLock';
    }
  } else {
    my ($i, %msg, %unids);

    $flocked = 1;

    ($threads, $last_thread, $last_message, my $unids) = get_all_threads (forum_filename, 1, 0);
    ($ftid,$fmid) = split /;/,$dparam{$formdata -> {followUp} -> {name}},2;

    # Thread existiert nicht
    if (exists($dparam{$formdata -> {followUp} -> {name}})) {
      return 'noReply' unless (exists($threads -> {$ftid}));

      # nur nicht geloeschte Messages beachten
      for ($i=0; $i < @{$threads -> {$ftid}}; $i++) {
        if ($threads -> {$ftid} -> [$i] -> {deleted}) {
          $i+=$threads -> {$ftid} -> [$i] -> {answers};}

        else {
          $msg{$threads -> {$ftid} -> [$i] -> {mid}}=$i;}}

      # Message existiert nicht
      if (exists($dparam{$formdata -> {followUp} -> {name}})) {
        return 'noReply' unless (exists($msg{$fmid}));}

      %unids = map {$_ => 1} @{$threads -> {$ftid} -> [$msg{$fmid}] -> {unids}};
    } else {
      %unids = map {$_ => 1} @$unids;
    }

    # jetzt endlich
    return 'Dupe' if (exists ($unids{$dparam{$formdata -> {uniqueID} -> {name}}}));
  }

  return;
}

################################
# sub got_new
#
# Eroeffnungsposting speichern
################################

sub got_new () {

  my $time = time;
  my $pars = {author        => $dparam {$formdata -> {posterName} -> {name}},
              email         => $dparam {$formdata -> {posterEmail} -> {name}},
              category      => $dparam {$formdata -> {posterCategory} -> {name}},
              subject       => $dparam {$formdata -> {posterSubject} -> {name}},
              body          => $dparam {$formdata -> {posterBody} -> {name}},
              homepage      => $dparam {$formdata -> {posterURL} -> {name}},
              image         => $dparam {$formdata -> {posterImage} -> {name}},
              time          => $time,
              uniqueID      => $dparam {$formdata -> {uniqueID} -> {name}},
              ip            => $ENV{REMOTE_ADDR},
              forumFile     => forum_filename,
              messagePath   => message_path,
              lastThread    => $last_thread,
              lastMessage   => $last_message,
              parsedThreads => $threads,
              dtd           => 'forum.dtd',
              quoteChars    => toUTF8('»» '),
              messages      => $conf -> {template} -> {messages}};

  my ($stat, $xml, $mid) = write_posting ($pars);
  violent_unlock_file (forum_filename) unless (write_unlock_file (forum_filename));
  $flocked = undef;

  if ($stat) {
    print "Och noe...: $stat";}

  else {
    my $thx = $show_posting -> {thanx};

    print ${$template -> scrap ($assign -> {docThx},
                               {$thx -> {author}   => plain ($dparam {$formdata -> {posterName} -> {name}}),
                                $thx -> {email}    => plain ($dparam {$formdata -> {posterEmail} -> {name}}),
                                $thx -> {time}     => plain (hr_time($time)),
                                $thx -> {body}     => message_as_HTML ($xml, $template,
                                                                      {posting => $mid,
                                                                       assign  => $assign}),
                                $thx -> {category} => plain ($dparam {$formdata -> {posterCategory} -> {name}}),
                                $thx -> {home}     => plain ($dparam {$formdata -> {posterURL} -> {name}}),
                                $thx -> {image}    => plain ($dparam {$formdata -> {posterImage} -> {name}}),
                                $thx -> {subject}  => plain ($dparam {$formdata -> {posterSubject} -> {name}})})};
  }
  return;
}

################################
# sub got_reply
#
# Antwortposting speichern
################################

sub got_reply () {
  my $stat;

  my $time = time;
  my $pars = {author        => $dparam {$formdata -> {posterName} -> {name}},
              email         => $dparam {$formdata -> {posterEmail} -> {name}},
              category      => $dparam {$formdata -> {posterCategory} -> {name}},
              subject       => $dparam {$formdata -> {posterSubject} -> {name}},
              body          => $dparam {$formdata -> {posterBody} -> {name}},
              homepage      => $dparam {$formdata -> {posterURL} -> {name}},
              image         => $dparam {$formdata -> {posterImage} -> {name}},
              time          => $time,
              uniqueID      => $dparam {$formdata -> {uniqueID} -> {name}},
              ip            => $ENV{REMOTE_ADDR},
              parentMessage => $fmid,
              thread        => $ftid,
              forumFile     => forum_filename,
              messagePath   => message_path,
              lastThread    => $last_thread,
              lastMessage   => $last_message,
              parsedThreads => $threads,
              dtd           => 'forum.dtd',
              quoteChars    => toUTF8('»» '),
              messages      => $conf -> {template} -> {messages}};

  ($stat, my $xml, my $mid) = write_posting ($pars);
  violent_unlock_file (forum_filename) unless (write_unlock_file (forum_filename));
  $flocked = undef;

  if ($stat) {
    print "Och noe...: $stat";}

  else {
    my $thx = $show_posting -> {thanx};

    print ${$template -> scrap ($assign -> {docThx},
                               {$thx -> {author}   => plain ($dparam {$formdata -> {posterName} -> {name}}),
                                $thx -> {email}    => plain ($dparam {$formdata -> {posterEmail} -> {name}}),
                                $thx -> {time}     => plain (hr_time($time)),
                                $thx -> {body}     => message_as_HTML ($xml, $template,
                                                                      {posting => $mid,
                                                                       assign  => $assign}),
                                $thx -> {category} => plain ($dparam {$formdata -> {posterCategory} -> {name}}),
                                $thx -> {home}     => plain ($dparam {$formdata -> {posterURL} -> {name}}),
                                $thx -> {image}    => plain ($dparam {$formdata -> {posterImage} -> {name}}),
                                $thx -> {subject}  => plain ($dparam {$formdata -> {posterSubject} -> {name}})})};}
}

################################
# sub new_thread
#
# HTML fuer Eroeffnungsposting
################################

sub new_thread () {
  my $list = [map {{$assign -> {optval} => plain($_)}} @{$formdata -> {posterCategory} -> {values}}];

  # spaeter kommen noch userspezifische Daten dazu...
  print ${$template -> scrap ($assign -> {docNew},
                             {$formdata->{uniqueID}      ->{assign}->{value} => plain(unique_id),
                              $formdata->{quoteChar}     ->{assign}->{value} => '&#255;'.plain(toUTF8('»» ')),
                              $formact->{post}->{assign}                     => $formact->{post}->{url},
                              $formdata->{posterCategory}->{assign}->{value} => $template->list ($assign -> {option}, $list)
                             },$pars)};
}

################################
# diverse subs
#
# Fehlermeldungen
################################

sub no_reply ()         {&print_fatal ($assign -> {noReply});}
sub dupe_posting ()     {&print_fatal ($assign -> {dupe});}
sub missing_key ()      {&print_fatal ($assign -> {wrongPar});}
sub unexpected_key ()   {&print_fatal ($assign -> {wrongPar});}
sub unknown_encoding () {&print_fatal ($assign -> {wrongCode});}
sub too_short () {
  if ($formdata -> {$failed} -> {errorType} eq 'repeat') {
    &print_error ($formdata -> {$failed} -> {assign} -> {tooShort},
                  $formdata -> {$failed} -> {minlength});}

  else {
    &print_fatal ($formdata -> {$failed} -> {assign} -> {tooShort});}
}

sub too_long () {
  if ($formdata -> {$failed} -> {errorType} eq 'repeat') {
    &print_error ($formdata -> {$failed} -> {assign} -> {tooLong},
                  $formdata -> {$failed} -> {maxlength});}

  else {
    &print_fatal ($formdata -> {$failed} -> {assign} -> {tooLong});}
}

sub wrong_mail () {print_error ($formdata -> {$failed} -> {assign} -> {wrong});}
sub occupied () {print_error ($assign -> {occupied});}

################################
# sub print_fatal
#
# fatale Fehlerausgabe
################################

sub print_fatal ($) {
  print ${$template -> scrap ($assign -> {docFatal},
                             {$assign -> {errorMessage} => $template -> insert ($_[0])
                             },$pars)};
}

################################
# sub print_error
#
# Fehlerausgabe, Moeglichkeit
# zur Korrektur
################################

sub print_error ($;$) {
  &fillin;
  print ${$template -> scrap ($assign -> {docError},
                             {$assign -> {errorMessage} => $template -> insert ($_[0]),
                              $assign -> {charNum}      => $_[1]
                             },$pars)};
}

################################
# sub fetch_subject
#
# Subject und Category besorgen
# (wenn noch nicht vorhanden)
################################

sub fetch_subject () {
  unless (exists ($dparam{$formdata -> {posterCategory} -> {name}}) and
          exists ($dparam{$formdata -> {posterSubject} -> {name}})) {

    my $filename = message_path.'t'.$ftid.'.xml';

    if (lock_file ($filename)) {
      my $xml = new XML::DOM::Parser -> parsefile ($filename);
      violent_unlock_file($filename) unless unlock_file ($filename);

      my $mnode = get_message_node ($xml, "t$ftid", "m$fmid");
      my $header = get_message_header ($mnode);

      $dparam{$formdata -> {posterCategory} -> {name}} = $header -> {category};
      $dparam{$formdata -> {posterSubject} -> {name}} = $header -> {subject};}}
}

################################
# sub fillin
#
# Fuellen von $pars
# (bereits vorhandene Formdaten)
################################

sub fillin () {
  fetch_subject;

  my $list = [map {{$assign -> {optval} => plain($_),
                    (($_ eq $dparam{$formdata -> {posterCategory} -> {name}})?($assign -> {optsel} => 1):())}}
                @{$formdata -> {posterCategory} -> {values}}];

  $pars -> {$formdata->{posterCategory}->{assign}->{value}} = $template->list ($assign -> {option}, $list);
  $pars -> {$formact ->{post}->{assign}}                    = $formact->{post}->{url};
  $pars -> {$formdata->{quoteChar}->{assign}->{value}}      = '&#255;'.plain($dparam {$formdata -> {quoteChar} -> {name}} or '');

  # Formfelder ausfuellen (Werte)
  for (qw(uniqueID userID followUp posterName posterEmail posterSubject posterBody posterURL posterImage)) {
    $pars -> {$formdata->{$_}->{assign}->{value}} = plain($dparam {$formdata -> {$_} -> {name}});}
}

################################
# sub decode_param
#
# CGI-Parameter decodieren
# (rudimentaerer UTF8-support)
################################

sub decode_param () {
  my $code = param ($formdata -> {quoteChar} -> {name});
  my @array;

  # UTF-8 ([hoechst-]wahrscheinlich)
  if ($code =~ /^\303\277/) {

    foreach (param) {
      @array=param ($_);

      if (@array == 1) {
        $dparam{$_} = $array[0];}

      else {
        $dparam{$_} = \@array;}}}

  # Latin 1 (hoffentlich - eigentlich ist es gar keine Codierung...)
  elsif ($code =~ /^\377/) {
    foreach (param) {
      @array=param ($_);

      if (@array == 1) {
        $dparam{$_} = toUTF8($array[0]);}

      else {
        $dparam{$_} = [map {toUTF8($_)} @array];}}}

  # unbekannte Codierung
  else {
    return;}

  # ersten beiden Zeichen der Quotechars loeschen (Indikator [&#255; (als UTF8)])
  $dparam {$formdata -> {quoteChar} -> {name}} = ($dparam {$formdata -> {quoteChar} -> {name}} =~ /..(.*)/)[0];

  delete $dparam {$formdata -> {posterURL} -> {name}}
    unless ($dparam {$formdata -> {posterURL} -> {name}} =~ /$httpurl/);

  delete $dparam {$formdata -> {posterImage} -> {name}}
    unless ($dparam {$formdata -> {posterImage} -> {name}} =~ /$httpurl/);

  # Codierung erkannt, alles klar
  1;
}

################################
# sub check_param
#
# CGI-Parameter pruefen
################################

sub check_param () {
  my %gotKeys    = map {($_ => 1)} param;
  my $numGotKeys = keys %gotKeys;

  # Threaderoeffnung, Ersteingabe (leere Seite)
  return 'newThread' if ($numGotKeys == 0 or
                         (($numGotKeys == 1) and ($gotKeys {$formdata -> {userID} -> {name}})));

  # =======================================================
  # ab hier steht fest, wir haben ein ausgefuelltes
  # Formular bekommen
  #
  # 1. Umrechnungshash bauen (CGI-Key => Identifier)
  # 2. alle must-keys vorhanden?
  # 3. zuviele Parameter uebermittelt?
  # 4. entsprechen die Daten den Anforderungen?
  #    (alle, nicht nur die must-Daten)

  # 1
  # ===
  my %name = map {($formdata -> {$_} -> {name} => $_)} keys %$formdata;

  # 2
  # ===
  $failed=1;
  foreach (@{$formmust -> {$gotKeys {$formdata -> {followUp} -> {name}}?'reply':'new'}}) {
    return 'missingKey' unless ($gotKeys {$formdata -> {$_} -> {name}});
  }

  # 3
  # ===
  foreach (param) {
    $failed = $name {$_};
    return 'unexpectedKey' unless (exists ($name {$_}));
  }

  # 4
  # ===
  return 'unknownEncoding' unless (decode_param);

  foreach (keys %dparam) {
    $failed = $name {$_};

    return 'tooLong'   if (length($dparam{$_}) > $formdata -> {$name {$_}} -> {maxlength});
    return 'tooShort'  if (@{[$dparam{$_} =~ /(\S)/g]} < $formdata -> {$name {$_}} -> {minlength});
    return 'wrongMail' if ($formdata -> {$name{$_}} -> {type} eq 'email' and length ($dparam{$_}) and not is_mail_address ($dparam{$_}));
  }

  $failed=0;
  return $gotKeys {$formdata -> {followUp} -> {name}}?'gotReply':'gotNew';
}

# ====================================================
# Initialisierung
# ====================================================

BEGIN {
  %subhash = (newThread       => \&new_thread,
              missingKey      => \&missing_key,
              unexpectedKey   => \&unexpected_key,
              unknownEncoding => \&unknown_encoding,
              tooShort        => \&too_short,
              tooLong         => \&too_long,
              wrongMail       => \&wrong_mail,
              Occupied        => \&occupied,
              Dupe            => \&dupe_posting,
              noReply         => \&no_reply,
              gotReply        => \&got_reply,
              gotNew          => \&got_new
              );

  # Die RFC-gerechte URL-Erkennung ist aus dem Forum
  # (thx2Cheatah - wo auch immer er sie (in der Form) her hat :-)
  my $lowalpha       =  '(?:[a-z])';
  my $hialpha        =  '(?:[A-Z])';
  my $alpha          =  "(?:$lowalpha|$hialpha)";
  my $digit          =  '(?:\d)';
  my $safe           =  '(?:[$_.+-])';
  my $hex            =  '(?:[\dA-Fa-f])';
  my $escape         =  "(?:%$hex$hex)";
  my $digits         =  '(?:\d+)';
  my $alphadigit     =  "(?:$alpha|\\d)";

  # URL schemeparts for ip based protocols:
  my $port           =  "(?:$digits)";
  my $hostnumber     =  "(?:$digits\\.$digits\\.$digits\\.$digits)";
  my $toplabel       =  "(?:(?:$alpha(?:$alphadigit|-)*$alphadigit)|$alpha)";
  my $domainlabel    =  "(?:(?:$alphadigit(?:$alphadigit|-)*$alphadigit)|$alphadigit)";
  my $hostname       =  "(?:(?:$domainlabel\\.)*$toplabel)";
  my $host           =  "(?:(?:$hostname)|(?:$hostnumber))";
  my $hostport       =  "(?:(?:$host)(?::$port)?)";

  my $httpuchar      =  "(?:(?:$alpha|$digit|$safe|(?:[!*\',]))|$escape)";
  my $hsegment       =  "(?:(?:$httpuchar|[;:\@&=~])*)";
  my $search         =  "(?:(?:$httpuchar|[;:\@&=~])*)";
  my $hpath          =  "(?:$hsegment(?:/$hsegment)*)";

  # das alles ergibt eine gueltige URL :-)
  $httpurl           =  "^(?:https?://$hostport(?:/$hpath(?:\\?$search)?)?)\$";
}

# ====================================================
# end of fo_posting.pl
# ====================================================