# Posting/Write.pm

# ====================================================
# Autor: n.d.p. / 2001-01-29
# lm   : n.d.p. / 2001-02-25
# ====================================================
# Funktion:
#      Speicherung eines Postings
# ====================================================

use strict;

package Posting::Write;

use vars qw(@EXPORT);
use base qw(Exporter);

# ====================================================
# Funktionsexport
# ====================================================

@EXPORT = qw(write_posting);

use Encode::Plain; $Encode::Plain::utf8 = 1;
use Encode::Posting;
use Lock qw(:WRITE release_file);
use Posting::_lib qw(get_message_node get_message_header create_forum_xml_string save_file);

use XML::DOM;

################################
# sub write_posting
#
# Neues Posting speichern
################################

sub write_posting ($) {
  my $param = shift;
  my ($thread,$tid);
  my $mid   = 'm'.($param -> {lastMessage} + 1);

  my $pars = {quoteChars => $param -> {quoteChars},
              messages   => $param -> {messages}};

  my %error = (threadWrite => '1 could not write thread file',
               forumWrite  => '2 could not write forum file',
               threadFile  => '3 could not load thread file',
               noParent    => '4 could not find parent message');

  # neue Nachricht
  unless ($param -> {parentMessage}) {
    $tid   = 't'.($param -> {lastThread} + 1);
    $thread = create_new_thread ({msg      => $mid,
                                  ip       => $param -> {ip},
                                  name     => $param -> {author},
                                  email    => $param -> {email},
                                  home     => $param -> {homepage},
                                  image    => $param -> {image},
                                  category => $param -> {category},
                                  subject  => $param -> {subject},
                                  time     => $param -> {time},
                                  dtd      => $param -> {dtd},
                                  thread   => $tid,
                                  body     => $param -> {body},
                                  pars     => $pars});

    save_file ($param -> {messagePath}.$tid.'.xml',\($thread -> toString)) or return $error{threadWrite};

    # Thread eintragen
    $param -> {parsedThreads}
           -> {$param -> {lastThread} + 1} = [{mid     => $param -> {lastMessage} + 1,
                                               unid    => $param -> {uniqueID},
                                               name    => plain($param -> {author}),
                                               cat     => plain(length($param -> {category})?$param->{category}:''),
                                               subject => plain($param -> {subject}),
                                               time    => plain($param -> {time})}];

    my $forum = create_forum_xml_string ($param -> {parsedThreads},
                                        {dtd         => $param -> {dtd},
                                         lastMessage => $mid,
                                         lastThread  => $tid});

    save_file ($param -> {forumFile}, $forum) or return $error{forumWrite};
    release_file ($param -> {messagePath}.$tid.'.xml');
    return (0, $thread, $mid);}

  # Reply
  else {
    $tid   = 't'.($param -> {thread});
    my $tfile = $param -> {messagePath}.$tid.'.xml';
    my $xml;

    unless (write_lock_file ($tfile)) {
      violent_unlock_file ($tfile);
      return $error{threadFile};}

    else {
      $xml = eval {local $SIG{__DIE__}; new XML::DOM::Parser (KeepCDATA => 1) -> parsefile ($tfile);};

      if ($@) {
        violent_unlock_file ($tfile) unless (write_unlock_file ($tfile));
        return $error{threadFile};}

      my $mnode = get_message_node ($xml, $tid, 'm'.$param -> {parentMessage});

      unless (defined $mnode) {
        violent_unlock_file ($tfile) unless (write_unlock_file ($tfile));
        return $error{noParent};}

      my $pheader = get_message_header ($mnode);

      my $message = create_message ($xml,
                                   {msg      => $mid,
                                    ip       => $param -> {ip},
                                    name     => $param -> {author},
                                    email    => $param -> {email},
                                    home     => $param -> {homepage},
                                    image    => $param -> {image},
                                    category => length($param -> {category})?$param -> {category}:$pheader -> {category},
                                    subject  => length($param -> {subject})?$param -> {subject}:$pheader -> {subject},
                                    time     => $param -> {time},
                                    pars     => $pars});

      $mnode -> appendChild ($message);

      my $mcontent = $xml -> createElement ('MessageContent');
         $mcontent -> setAttribute ('mid', $mid);
         $mcontent -> appendChild ($xml -> createCDATASection (${encoded_body(\($param -> {body}), $pars)}));

      my $content = $xml -> getElementsByTagName ('ContentList', 1) -> item (0);
         $content -> appendChild ($mcontent);

      unless (save_file ($tfile, \($xml -> toString))) {
        violent_unlock_file ($tfile) unless (write_unlock_file ($tfile));
        return $error{threadWrite};}

      violent_unlock_file ($tfile) unless (write_unlock_file ($tfile));

      $thread = $xml;

      # Message eintragen
      # ACHTUNG! danach kann der Threadbaum nicht mehr fuer die visuelle
      # Ausgabe genutzt werden, da die answers nicht angepasst werden
      # (und somit nicht mehr stimmen...)

      my $i=1;
      my $cat  = length($param -> {category})?$param -> {category}:$pheader -> {category};
      my $subj = length($param -> {subject})?$param -> {subject}:$pheader -> {subject};

      for (@{$param -> {parsedThreads} -> {$param -> {thread}}}) {
        if ($_ -> {mid} == $param -> {parentMessage}) {
          splice @{$param -> {parsedThreads} -> {$param -> {thread}}},$i,0,
            {mid     => $param -> {lastMessage} + 1,
             unid    => $param -> {uniqueID},
             name    => plain ($param -> {author}),
             cat     => plain(length($cat)?$cat:''),
             subject => plain(length($subj)?$subj:''),
             level   => $_ -> {level} + 1,
             time    => plain ($param -> {time})};
          last;}
        $i++;}

      my $forum = create_forum_xml_string ($param -> {parsedThreads},
                                          {dtd         => $param -> {dtd},
                                           lastMessage => $mid,
                                           lastThread  => 't'.$param -> {lastThread}});

      save_file ($param -> {forumFile}, $forum) or return $error{forumWrite};}

  return (0, $thread, $mid);}
}

# ====================================================
# Private Funktionen
# ====================================================

sub create_message ($$) {
  my ($xml,$par) = @_;

  my $message = $xml -> createElement ('Message');
  $message -> setAttribute ('id', $par -> {msg});
  $message -> setAttribute ('ip', $par -> {ip});

  # Header erzeugen
  my $header = $xml -> createElement ('Header');

  # alles inside of 'Header'
  my $author   = $xml -> createElement ('Author');
    my $name  = $xml -> createElement ('Name');
    $name -> addText ($par -> {name});
    $author -> appendChild ($name);

    my $email = $xml -> createElement ('Email');
    $email -> addText ($par -> {email});
    $author -> appendChild ($email);

    if (length ($par -> {home})) {
      my $home  = $xml -> createElement ('HomepageUrl');
      $home -> addText ($par -> {home});
      $author -> appendChild ($home);}

    if (length ($par -> {image})) {
      my $image = $xml -> createElement ('ImageUrl');
      $image -> addText ($par -> {image});
      $author -> appendChild ($image);}

  my $category = $xml -> createElement ('Category');
  $category -> addText ($par -> {category});

  my $subject  = $xml -> createElement ('Subject');
  $subject -> addText ($par -> {subject});

  my $date     = $xml -> createElement ('Date');
  $date -> setAttribute ('longSec', $par -> {time});

    $header -> appendChild ($author);
    $header -> appendChild ($category);
    $header -> appendChild ($subject);
    $header -> appendChild ($date);
  $message -> appendChild ($header);

  $message;
}

sub create_new_thread ($) {
  my $par = shift;

  # neues Dokument
  my $xml = new XML::DOM::Document;

  # XML-declaration
  my $decl = new XML::DOM::XMLDecl;
  $decl -> setVersion  ('1.0');
  $decl -> setEncoding ('UTF-8');
  $xml -> setXMLDecl ($decl);

  # Doctype
  my $dtd = $xml -> createDocumentType ('Forum', $par -> {dtd}, undef, undef);
  $xml -> setDoctype ($dtd);

  # Root erzeugen
  my $forum = $xml -> createElement ('Forum');

  # Thread erzeugen
  my $thread = $xml -> createElement ('Thread');
  $thread -> setAttribute ('id', $par -> {thread});

  # Message erzeugen
  my $message = create_message ($xml,$par);

  # Contentlist
  my $content  = $xml -> createElement ('ContentList');
  my $mcontent = $xml -> createElement ('MessageContent');
  $mcontent -> setAttribute ('mid', $par -> {msg});
  $mcontent -> appendChild ($xml -> createCDATASection (${encoded_body(\($par -> {body}), $par -> {pars} )}));

  # die ganzen Nodes verknuepfen
      $thread -> appendChild ($message);
    $forum -> appendChild ($thread);

      $content -> appendChild ($mcontent);
    $forum -> appendChild ($content);

  $xml -> appendChild ($forum);

  # und fertiges Dokument zurueckgeben
  $xml;
}

# ====================================================
# Modulinitialisierung
# ====================================================

# making require happy
1;

# ====================================================
# end of Posting::Write
# ====================================================