package Posting::Write;

################################################################################
#                                                                              #
# File:        shared/Posting/Write.pm                                         #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>, 2001-04-08                          #
#                                                                              #
# Description: Save a posting                                                  #
#                                                                              #
################################################################################

use strict;
use vars qw(%error @EXPORT);

use Encode::Plain; $Encode::Plain::utf8 = 1;
use Encode::Posting;
use Lock qw(
  :WRITE
  release_file
);
use Posting::_lib qw(
  get_message_node
  get_message_header
  create_forum_xml_string
  create_new_thread
  create_message
  save_file
  parse_xml_file
  KEEP_DELETED
);

use XML::DOM;

%error = (
  threadWrite => '1 could not write thread file',
  forumWrite  => '2 could not write forum file',
  threadFile  => '3 could not load thread file',
  noParent    => '4 could not find parent message'
);

################################################################################
#
# Export
#
use base qw(Exporter);
@EXPORT = qw(
  write_new_thread
  write_reply_posting
);

### sub write_new_thread ($) ###################################################
#
# save a posting and update the forum main file
#
# Params: $param - hashreference
#                  (see doc for details)
#
# Return: (0 or error, thread-xml, new mid)
#
sub write_new_thread ($) {
  my $param = shift;
  my $thread;
  my $mid   = 'm'.($param -> {lastMessage} + 1);
  my $tid   = 't'.($param -> {lastThread} + 1);

  # define the params needed for a new thread
  #
  my $pars = {
    msg      => $mid,
    ip       => $param -> {ip},
    name     => defined $param -> {author}   ? $param -> {author}   : '',
    email    => defined $param -> {email}    ? $param -> {email}    : '',
    home     => defined $param -> {homepage} ? $param -> {homepage} : '',
    image    => defined $param -> {image}    ? $param -> {image}    : '',
    category => defined $param -> {category} ? $param -> {category} : '',
    subject  => defined $param -> {subject}  ? $param -> {subject}  : '',
    body     => encoded_body(
      \($param -> {body}),
      { quoteChars => $param -> {quoteChars},
        messages   => $param -> {messages},
        base_uri   => $param -> {base_uri}
      }
    ),
    time     => $param -> {time},
    dtd      => $param -> {dtd},
    thread   => $tid
  };

  # create new thread and save it to disk
  #
  $thread = create_new_thread ($pars);
  save_file ($param -> {messagePath}.$tid.'.xml',\($thread -> toString)) or return $error{threadWrite};

  # update forum main file
  #
  $param
    -> {parsedThreads}
    -> {$param -> {lastThread} + 1} = [
        { mid     => $param -> {lastMessage} + 1,
          unid    => $param -> {uniqueID},
          name    => plain($pars -> {name}),
          cat     => plain($pars -> {category}),
          subject => plain($pars -> {subject}),
          time    => plain($pars -> {time}),
          level   => 0,
        }
       ];

  my $forum = create_forum_xml_string (
    $param -> {parsedThreads},
    { dtd         => $pars -> {dtd},
      lastMessage => $mid,
      lastThread  => $tid
    }
  );

  save_file ($param -> {forumFile}, $forum) or return $error{forumWrite};
  release_file ($param -> {messagePath}.$tid.'.xml');
  return (0, $thread, $mid);
}

### sub write_reply_posting ($) ################################################
#
# save a reply and update the forum main file
#
# Params: $param - hashreference
#                  (see doc for details)
#
# Return: (0 or error, thread-xml, new mid)
#
sub write_reply_posting ($) {
  my $param = shift;
  my $thread;
  my $mid   = 'm'.($param -> {lastMessage} + 1);
  my $tid   = 't'.($param -> {thread});

  my $tfile = $param -> {messagePath}.$tid.'.xml';

  unless (write_lock_file ($tfile)) {
    violent_unlock_file ($tfile);
    return $error{threadFile};
  }

  else {
    my $xml = parse_xml_file ($tfile);

    unless ($xml) {
      violent_unlock_file ($tfile) unless (write_unlock_file ($tfile));
      return $error{threadFile};
    }

    my $mnode = get_message_node ($xml, $tid, 'm'.$param -> {parentMessage});

    unless (defined $mnode) {
      violent_unlock_file ($tfile) unless (write_unlock_file ($tfile));
      return $error{noParent};
    }

    my $pars = {
      msg      => $mid,
      ip       => $param -> {ip},
      name     => defined $param -> {author}   ? $param -> {author}   :'',
      email    => defined $param -> {email}    ? $param -> {email}    :'',
      home     => defined $param -> {homepage} ? $param -> {homepage} :'',
      image    => defined $param -> {image}    ? $param -> {image}    :'',
      category => defined $param -> {category} ? $param -> {category} :'',
      subject  => defined $param -> {subject}  ? $param -> {subject}  :'',
      time     => $param -> {time},
    };

    my $message = create_message ($xml, $pars);

    $mnode -> appendChild ($message);

    my $mcontent = $xml -> createElement ('MessageContent');
    $mcontent -> setAttribute ('mid' => $mid);
    $mcontent -> appendChild (
      $xml -> createCDATASection (
        ${encoded_body(
          \($param -> {body}),
          { quoteChars => $param -> {quoteChars},
            messages   => $param -> {messages},
            base_uri   => $param -> {base_uri}
          }
        )}
      )
    );

    my $content = $xml -> getElementsByTagName ('ContentList', 1) -> item (0);
       $content -> appendChild ($mcontent);

    # save thread file
    #
    unless (save_file ($tfile, \($xml -> toString))) {
      violent_unlock_file ($tfile) unless (write_unlock_file ($tfile));
      return $error{threadWrite};
    }

    violent_unlock_file ($tfile) unless (write_unlock_file ($tfile));

    $thread = $xml;

    # add message to thread tree
    # ATTENTION: don't use the tree for visual output after this operation
    #
    my $i=1;
    for (@{$param -> {parsedThreads} -> {$param -> {thread}}}) {
      if ($_ -> {mid} == $param -> {parentMessage}) {
        splice @{
          $param -> {parsedThreads} -> {$param -> {thread}}},$i, 0,
          { mid     => $param -> {lastMessage} + 1,
            unid    => plain ($param -> {uniqueID}),
            name    => plain ($pars -> {name}),
            cat     => plain ($pars -> {category}),
            subject => plain ($pars -> {subject}),
            level   => $_ -> {level} + 1,
            time    => plain ($pars -> {time})
          };
        last;
      }
      $i++;
    }

    # create & save forum main file
    #
    my $forum = create_forum_xml_string (
      $param -> {parsedThreads},
      { dtd         => $param -> {dtd},
        lastMessage => $mid,
        lastThread  => $tid
      }
    );

    save_file ($param -> {forumFile}, $forum) or return $error{forumWrite};
  }

  return (0, $thread, $mid);
}

# keep 'require' happy
#
1;

#
#
### end of Posting::Write ######################################################