package Posting::_lib;

################################################################################
#                                                                              #
# File:        shared/Posting/_lib.pm                                          #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>, 2001-03-03                          #
#              Frank Schoenmann <fs@tower.de>, 2001-06-04                      #
#                                                                              #
# Description: Message access interface, time format routines                  #
#                                                                              #
################################################################################

use strict;

use Encode::Plain; $Encode::Plain::utf8 = 1;

use XML::DOM;

# ====================================================
# Export
# ====================================================

use constant SORT_ASCENT  => 0; # (young postings first)
use constant SORT_DESCENT => 1;
use constant KEEP_DELETED => 1;
use constant KILL_DELETED => 0;

use base qw(Exporter);
@Posting::_lib::EXPORT_OK = qw(
  get_message_header
  get_message_body
  get_message_node
  get_body_node
  parse_single_thread
  parse_xml_file
  create_new_thread
  create_message

  hr_time
  short_hr_time
  long_hr_time
  month

  get_all_threads
  create_forum_xml_string

  save_file

  SORT_ASCENT
  SORT_DESCENT
  KEEP_DELETED
  KILL_DELETED
);

# ====================================================
# Access via XML::DOM
# ====================================================

### sub create_message ($$) ####################################################
#
# create the 'Message' subtree
#
# Params: $xml - XML::DOM::Document object
#         $par - hash reference
#                (msg, ip, name, email, home, image, category, subject, time)
#
# Return: XML::DOM::Element object
#
sub create_message ($$) {
  my ($xml,$par) = @_;

  my $message = $xml -> createElement ('Message');
  $message -> setAttribute ('id' => $par -> {msg});
  $message -> setAttribute ('ip' => $par -> {ip});

  my $header = $xml -> createElement ('Header');
  my $author = $xml -> createElement ('Author');
  $header  -> appendChild ($author);

  my @may = (
    ['name'     => 'Name'        => $author],
    ['email'    => 'Email'       => $author],
    ['home'     => 'HomepageUrl' => $author],
    ['image'    => 'ImageUrl'    => $author],
    ['category' => 'Category'    => $header],
    ['subject'  => 'Subject'     => $header]
  );# key       => element name  => superior

  for (@may) {

    # create element
    my $obj = $xml -> createElement ($_->[1]);

    # insert content
    $obj -> addText (
        defined $par -> {$_->[0]}
      ? $par -> {$_->[0]}
      : ''
    );

    # link to superior element
    $_ -> [2] -> appendChild ($obj);
  }

  my $date = $xml -> createElement ('Date');
  $date -> setAttribute ('longSec'=> $par -> {time});

  $header  -> appendChild ($date);
  $message -> appendChild ($header);

  # return
  #
  $message;
}

### sub create_new_thread ($) ##################################################
#
# create a XML::DOM::Document object of a thread containing one posting
#
# Params: hash reference
#         (dtd, thread, msg, body, ip, name, email, home,
#          image, category, subject, time)
#
# Return: XML::DOM::Document object
#
sub create_new_thread ($) {
  my $par = shift;

  # new document
  #
  my $xml = new XML::DOM::Document;

  # xml declaration
  #
  my $decl = new XML::DOM::XMLDecl;
  $decl -> setVersion  ('1.0');
  $decl -> setEncoding ('UTF-8');
  $xml -> setXMLDecl ($decl);

  # set doctype
  #
  my $dtd = $xml -> createDocumentType ('Forum' => $par -> {dtd});
  $xml -> setDoctype ($dtd);

  # create root element 'Forum'
  # create element 'Thread'
  # create 'Message' subtree
  # create element 'ContentList'
  # create 'MessageContent' subtree
  #
  my $forum    = $xml -> createElement ('Forum');
  my $thread   = $xml -> createElement ('Thread');
    $thread -> setAttribute ('id' => $par -> {thread});
  my $message  = create_message ($xml,$par);
  my $content  = $xml -> createElement ('ContentList');
  my $mcontent = $xml -> createElement ('MessageContent');
    $mcontent -> setAttribute ('mid' => $par -> {msg});
    $mcontent -> appendChild (
      $xml -> createCDATASection (${$par -> {body}})
    );

  # link all the nodes to
  # their superior elements
  #
  $thread  -> appendChild ($message);
  $forum   -> appendChild ($thread);
  $content -> appendChild ($mcontent);
  $forum   -> appendChild ($content);
  $xml     -> appendChild ($forum);

  # return
  #
  $xml;
}

### get_message_header () ######################################################
#
# Read message header, return as a hash
#
# Params: $node - XML message node
# Return: hash reference (name, category, subject, email, home, image, time)
#
sub get_message_header ($)
{
  my $node = shift;
  my %conf;

  my $header    = $node   -> getElementsByTagName ('Header'     , 0) -> item (0);
    my $author  = $header -> getElementsByTagName ('Author'     , 0) -> item (0);
      my $name  = $author -> getElementsByTagName ('Name'       , 0) -> item (0);
      my $email = $author -> getElementsByTagName ('Email'      , 0) -> item (0);
      my $home  = $author -> getElementsByTagName ('HomepageUrl', 0) -> item (0);
      my $image = $author -> getElementsByTagName ('ImageUrl'   , 0) -> item (0);
    my $cat     = $header -> getElementsByTagName ('Category'   , 0) -> item (0);
    my $subject = $header -> getElementsByTagName ('Subject'    , 0) -> item (0);
    my $date    = $header -> getElementsByTagName ('Date'       , 0) -> item (0);

  %conf = (
    name     => ($name    -> hasChildNodes)?$name    -> getFirstChild -> getData:undef,
    category => ($cat     -> hasChildNodes)?$cat     -> getFirstChild -> getData:undef,
    subject  => ($subject -> hasChildNodes)?$subject -> getFirstChild -> getData:undef,
    email    => (defined ($email) and $email -> hasChildNodes)?$email -> getFirstChild -> getData:undef,
    home     => (defined ($home)  and $home  -> hasChildNodes)?$home  -> getFirstChild -> getData:undef,
    image    => (defined ($image) and $image -> hasChildNodes)?$image -> getFirstChild -> getData:undef,
    time     => $date -> getAttribute ('longSec')
  );

  \%conf;
}

### get_body_node () ########################################################
#
# Search a specific message body in a XML tree
#
# Params: $xml  XML::DOM::Document Object (Document Node)
#         $mid  Message ID
#
# Return: MessageContent XML node (or -none-)
#
sub get_body_node ($$)
{
  my ($xml, $mid) = @_;

  for ($xml -> getElementsByTagName ('ContentList', 1) -> item (0) -> getElementsByTagName ('MessageContent', 0)) {
    return $_ if ($_ -> getAttribute ('mid') eq $mid);
  }

  return;
}

### get_message_body () ########################################################
#
# Read message body
#
# Params: $xml  XML::DOM::Document Object (Document Node)
#         $mid  Message ID
#
# Return: Scalar reference
#
sub get_message_body ($$)
{
  my $cnode = get_body_node ($_[0], $_[1]);
  my $body;

  $body = ($cnode -> hasChildNodes)?$cnode -> getFirstChild -> getData:'' if $cnode;

  \$body;
}

### get_message_node () ########################################################
#
# Search a specific message in a XML tree
#
# Params: $xml  XML::DOM::Document Object (Document Node)
#         $tid  Thread ID
#         $mid  Message ID
#
# Return: Message XML node, Thread XML node (or -none-)
#
sub get_message_node ($$$)
{
  my ($xml, $tid, $mid) = @_;
  my ($mnode, $tnode);

  for ($xml->getElementsByTagName ('Thread')) {
    if ($_->getAttribute ('id') eq $tid) {
      $tnode = $_;

      for ($tnode -> getElementsByTagName ('Message')) {
        if ($_ -> getAttribute ('id') eq $mid) {
          $mnode = $_;
          last;
        }
      }
      last;
    }
  }

  wantarray
  ? ($mnode, $tnode)
  : $mnode;
}

### sub parse_xml_file ($) #####################################################
#
# load the specified XML-File and create the DOM tree
# this sub is only to avoid errors and to centralize the parse process
#
# Params: $file filename
#
# Return: XML::DOM::Document Object (Document Node) or false
#
sub parse_xml_file ($) {
  my $file = shift;

  my $xml = eval {
    local $SIG{__DIE__};      # CGI::Carp works unreliable ;-(
    new XML::DOM::Parser(KeepCDATA => 1)->parsefile ($file);
  };

  return if ($@);

  $xml;
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
               deleted => $_ -> getAttribute ('invisible'),
               archive => $_ -> getAttribute ('archive'),
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
  $message -> setAttribute ('invisible', '1') if ($msg -> {deleted});
  $message -> setAttribute ('archive', '1') if ($msg -> {archive});

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

### delete_messages () #########################################################
#
# Filter out deleted messages
#
# Params: $smsg  Reference of array of references of hashs
# Return: -none-
#
sub delete_messages ($) {
  my $smsg = shift;
  my ($z, $oldlevel, @path) = (0,0,0);

  while ($z <= $#{$smsg}) {

    if ($smsg -> [$z] -> {level} > $oldlevel) {
      push @path => $z;
      $oldlevel = $smsg -> [$z] -> {level};
    }
    elsif ($smsg -> [$z] -> {level} < $oldlevel) {
      splice @path, $smsg -> [$z] -> {level};
      push @path => $z;
      $oldlevel = $smsg -> [$z] -> {'level'};
    }
    else {
      $path[-1] = $z;
    }

    if ($smsg -> [$z] -> {deleted}) {
      my $n = $smsg -> [$z] -> {answers} + 1;
      $smsg -> [$_] -> {answers} -= $n for (@path);
      splice @$smsg, $z, $n;
    }
    else {
      $z++;
    }
  }

  return;
}

### get_all_threads () #########################################################
#
# Read and Parse the main file (without any XML-module, they are too slow)
#
# Params: $file     /path/to/filename of the main file
#         $deleted  hold deleted (invisible) messages in result (1) oder not (0)
#         $sorted   direction of message sort: descending (0) (default) or ascending (1)
# Return: scalar context: hash reference
#           list context: list (\%threads, $last_thread, $last_message, $dtd, \@unids)
#
sub get_all_threads ($$;$)
{
  my ($file, $deleted, $sorted) = @_;
  my ($last_thread, $last_message, $dtd, @unids, %threads);
  local (*FILE, $/);

  open FILE,"< $file" or return;
  my $xml = join '', <FILE>;
  close(FILE) or return;

  if (wantarray)
  {
    ($dtd)          = $xml =~ /<!DOCTYPE\s+\S+\s+SYSTEM\s+"([^"]+)">/;
    ($last_thread)  = map {/(\d+)/} $xml =~ /<Forum.+?lastThread="([^"]+)"[^>]*>/;
    ($last_message) = map {/(\d+)/} $xml =~ /<Forum.+?lastMessage="([^"]+)"[^>]*>/;
  }

  my $reg_msg = qr~(?:</Message>
                     |<Message\s+id="m(\d+)"\s+unid="([^"]*)"(?:\s+invisible="([^"]*)")?(?:\s+archive="([^"]*)")?[^>]*>\s*
                      <Header>[^<]*(?:<(?!Name>)[^<]*)*
                        <Name>([^<]+)</Name>[^<]*(?:<(?!Category>)[^<]*)*
                        <Category>([^<]*)</Category>\s*
                        <Subject>([^<]+)</Subject>\s*
                        <Date\s+longSec="(\d+)"[^>]*>\s*
                      </Header>\s*(?:(<)/Message>|(?=(<)Message\s*)))~sx;

  while ($xml =~ /<Thread id="t(\d+)">([^<]*(?:<(?!\/Thread>)[^<]*)*)<\/Thread>/g)
  {
    my ($tid, $thread) = ($1, $2);
    my ($level, $cmno, @msg, @stack) = (0);

    while ($thread =~ m;$reg_msg;g)
    {
      if (defined($10))
      {
        push @stack,$cmno if (defined $cmno);
        push @msg, {
          mid     => $1,
          unid    => $2,
          deleted => $3 || 0,
          archive => $4 || 0,
          name    => $5,
          cat     => $6,
          subject => $7,
          time    => $8,
          level   => $level++,
          unids   => [],
          kids    => [],
          answers => 0
        };

        if (defined $cmno)
        {
          push @{$msg[$cmno] -> {kids}}  => $#msg;
          push @{$msg[$cmno] -> {unids}} => $2;
        }
        else
        {
          push @unids => $2;
        }

        $msg[$_] -> {answers}++ for (@stack);

        $cmno=$#msg;

        $msg[-1] -> {name}    =~ s/&amp;/&/g;
        $msg[-1] -> {cat}     =~ s/&amp;/&/g;
        $msg[-1] -> {subject} =~ s/&amp;/&/g;

      }
      elsif (defined ($9))
      {
        push @msg, {
          mid     => $1,
          unid    => $2,
          deleted => $3 || 0,
          archive => $4 || 0,
          name    => $5,
          cat     => $6,
          subject => $7,
          time    => $8,
          level   => $level,
          unids   => [],
          kids    => [],
          answers => 0
        };

        if (defined $cmno)
        {
          push @{$msg[$cmno] -> {kids}}  => $#msg;
          push @{$msg[$cmno] -> {unids}} => $2;
          $msg[$cmno] -> {answers}++;
        }
        else
        {
          push @unids => $2;
        }

        $msg[$_] -> {answers}++ for (@stack);

        $msg[-1] -> {name}    =~ s/&amp;/&/g;
        $msg[-1] -> {cat}     =~ s/&amp;/&/g;
        $msg[-1] -> {subject} =~ s/&amp;/&/g;
      }
      else
      {
        $cmno = pop @stack; $level--;
      }
    }

    my $smsg = sort_thread (\@msg, $sorted);    # sort messages
    delete_messages ($smsg) unless ($deleted);  # remove invisible messages

    $threads{$tid} = $smsg if (@$smsg);
  }

  wantarray
    ? (\%threads, $last_thread, $last_message, $dtd, \@unids)
    : \%threads;
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
                  .(($msg -> {deleted})?' invisible="1"':'')
                  .(($msg -> {archive})?' archive="1"':'')
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

### save_file () ###############################################################
#
# Save a file
#
# Params: $filename  Filename
#         $content   File content as scalar reference
# Return: Status (1 - ok, 0 - error)
#
sub save_file ($$)
{
  my ($filename, $content) = @_;
  local *FILE;

  open FILE, ">$filename.temp" or return;

  unless (print FILE $$content)
  {
    close FILE;
    return;
  }

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
  my @month = (qw(Januar Februar), "M\303\244rz", qw(April Mai Juni Juli August September Oktober November Dezember));
                                   # ^^^^^^^^ - UTF8 #

  my (undef, $min, $hour, $day, $mon, $year) = localtime ($_[0]);

  sprintf ('%02d. %s %04d, %02d:%02d Uhr', $day, $month[$mon], $year+1900, $hour, $min);
}

sub short_hr_time ($) {
  my (undef, $min, $hour, $day, $mon, $year) = localtime ($_[0]);

  sprintf ('%02d. %02d. %04d, %02d:%02d Uhr', $day, $mon+1, $year+1900, $hour, $min);
}

sub long_hr_time ($) {
  my @month = (qw(Januar Februar), "M\303\244rz", qw(April Mai Juni Juli August September Oktober November Dezember));
                                   # ^^^^^^^^ - UTF8 #

  my @wday  = qw(Sonntag Montag Dienstag Mittwoch Donnerstag Freitag Samstag);
  my ($sek, $min, $hour, $day, $mon, $year, $wday) = localtime ($_[0]);

  sprintf ('%s, %02d. %s %04d, %02d:%02d:%02d Uhr', $wday[$wday], $day, $month[$mon], $year+1900, $hour, $min, $sek);
}

sub month($) {
    my @month = (qw(Januar Februar), "M\303\244rz", qw(April Mai Juni Juli August September Oktober November Dezember));
                                     # ^^^^^^^^ - UTF8 #

    return $month[$_[0]];
}

# ====================================================
# Modulinitialisierung
# ====================================================

# making require happy
1;
