package Posting::Admin;

################################################################################
#                                                                              #
# File:        shared/Posting/Admin.pm                                         #
#              (was: ~Handle.pm)                                               #
#                                                                              #
# Authors:     Frank Schönmann <fs@tower.de>                                   #
#              André Malo <nd@o3media.de>                                      #
#              Christian Kruse <ckruse@wwwtech.de>                             #
#                                                                              #
# Description: Allow administration of postings                                #
#                                                                              #
# Todo:        * Lock files before modification                                #
#              * Change body in change_posting_body()                          #
#                                                                              #
################################################################################

use strict;
use vars qw(
  @EXPORT
);

use Lock;
use Posting::_lib qw(
  parse_xml_file
  get_message_node
  save_file
  get_all_threads
  create_forum_xml_string
);

use XML::DOM;

################################################################################
#
# Version check
#
# last modified:
#    $Date$ (GMT)
# by $Author$
#
sub VERSION {(q$Revision$ =~ /([\d.]+)\s*$/)[0] or '0.0'}

################################################################################
#
# Export
#
use base qw(Exporter);

@EXPORT = qw(
  hide_posting
  recover_posting
  modify_posting
  add_user_vote
  level_vote
);

### add_user_vote () ###########################################################
#
# Increase number of user votes (only in thread file)
#
# Params: $forum  Path and filename of forum
#         $tpath  Path to thread files
#         \%info  Hash reference: 'thread', 'posting', 'percent'
# Return: Status code (Bool)
#
# Todo:
#  * Lock files before modification
#
sub add_user_vote ($$$) {
  my ($forum, $tpath, $info) = @_;
  my ($tid, $mid, $percent) = ($info->{'thread'},
                               $info->{'posting'},
                               $info->{'percent'});

  # Thread
  my $tfile = $tpath . '/t' . $tid . '.xml';
  my $xml   = parse_xml_file($tfile);

  my $mnode = get_message_node($xml, $tid, $mid);
  my $votes = $mnode->getAttribute('votingUser') + 1;
  $mnode->setAttribute('votingUser', $votes);

  return save_file($tfile, \$xml->toString);
}

### level_vote () ##############################################################
#
# Set 1st or 2nd level voting (only in thread file)
#
# Params: $forum  Path and filename of forum
#         $tpath  Path to thread files
#         \%info  Hash reference: 'thread', 'posting', 'level', 'value'
# Return: Status code (Bool)
#
# Todo:
#  * Lock files before modification
#
sub level_vote {
  my ($forum, $tpath, $info) = @_;
  my ($tid, $mid, $level, $value) = ($info->{'thread'},
                                     $info->{'posting'},
                                     $info->{'level'},
                                     $info->{'value'});

  # Thread
  my $tfile = $tpath . '/t' . $tid . '.xml';
  my $xml = parse_xml_file($tfile);
  my $mnode = get_message_node($xml, $tid, $mid);

  unless (defined $value) {
    removeAttribute($level);
  }
  else {
    $mnode->setAttribute($level, $value);
  }

  return save_file($tfile, \$xml->toString);
}

### hide_posting () ############################################################
#
# Hide a posting: set 'invisible' flag
#
# Params: $forum  Path and filename of forum
#         $tpath  Path to thread files
#         \%info  Hash reference: 'thread', 'posting'
# Return: -none-
#
sub hide_posting($$$) {
  my ($forum, $tpath, $info) = @_;
  my ($tid, $mid) = ($info->{'thread'},
                     $info->{'posting'});

  # Thread
  my $tfile = $tpath . '/t' . $tid . '.xml';

  # lock files
  my $main  = new Lock $forum;
  my $tlock = new Lock $tfile;

  return unless $tlock->lock(LH_EXCL); # lock failed
  unless ($main->lock(LH_EXCL)) { # lock failed
    $tlock->unlock;
    return;
  }

  #
  # Change invisibility in the thread file.
  #
  unless (change_posting_visibility($tfile, 't'.$tid, 'm'.$mid, 1)) { # saving failed
    $tlock->unlock;
    $main->unlock;
    return;
  }

  # get all Forum threads
  my ($f, $lthread, $lmsg,$dtd) = get_all_threads($forum, 1);
  unless ($f) {
    $tlock->unlock;
    $main->unlock;
  }

  #
  # Change invisibility in the main forum index.
  #
  for my $i (0 .. $#{$f->{$tid}}) {
    if ($f->{$tid}->[$i]->{'mid'} == $mid) {
      $f->{$tid}->[$_]->{'deleted'} = 1 for ($i .. $i+$f->{$tid}->[$i]->{'answers'});
      last;
    }
  }

  my $success = save_file($forum,
                          create_forum_xml_string($f,
                                                  {
                                                    'dtd'         => $dtd,
                                                    'lastMessage' => $lmsg,
                                                    'lastThread'  => $lthread
                                                  })
                         );

  $tlock->unlock;
  $main->unlock;

  return $success;
}

### recover_posting() ##########################################################
#
# Recover a posting: delete 'invisible' flag
#
# Params: $forum  Path and filename of forum
#         $tpath  Path to thread files
#         \%info  Hash reference: 'thread', 'posting'
# Return: success or unsuccess
#
sub recover_posting ($$$) {
  my ($forum, $tpath, $info) = @_;
  my ($tid, $mid) = ($info->{'thread'},
                     $info->{'posting'});

  # Thread
  my $tfile = $tpath . '/t' . $tid . '.xml';

  # lock files
  my $main  = new Lock $forum;
  my $tlock = new Lock $tfile;

  return unless $tlock->lock(LH_EXCL); # lock failed
  unless ($main->lock(LH_EXCL)) { # lock failed
    $tlock->unlock;
    return;
  }

  #
  # Change invisibility in the thread file.
  #
  unless (change_posting_visibility($tfile, 't'.$tid, 'm'.$mid, 0)) { # saving failed
    $main->unlock;
    $tlock->unlock;
    return;
  }

  # get all Forum threads
  my ($f, $lthread, $lmsg,$dtd) = get_all_threads($forum,1);

  unless ($f) {
    $main->unlock;
    $tlock->unlock;

    return;
  }

  #
  # Change invisibility in the main forum index.
  #
  for my $i (0 .. $#{$f->{$tid}}) {
    if ($f->{$tid}->[$i]->{'mid'} == $mid) {
      $f->{$tid}->[$_]->{'deleted'} = 0 for ($i .. $i+$f->{$tid}->[$i]->{'answers'});
      last;
    }
  }

  my $success = save_file($forum,
                          create_forum_xml_string($f,
                                                  {
                                                    'dtd'         => $dtd,
                                                    'lastMessage' => $lmsg,
                                                    'lastThread'  => $lthread
                                                  })
                         );

  $tlock->unlock;
  $main->unlock;

  return $success;
}

### change_posting_visibility () ###############################################
#
# Set a postings visibility flag to $invisible
#
# Params: $fname      Filename
#         $tid        Thread ID
#         $mid        Message ID
#         $invisible  1 - invisible, 0 - visible
# Return: Status code
#
sub change_posting_visibility($$$$) {
  my ($fname, $tid, $mid, $invisible) = @_;

  my $xml = parse_xml_file($fname);
  return unless $xml; # parser failed

  # Set flag in given msg
  my $mnode = get_message_node($xml, $tid, $mid);
  $mnode->setAttribute('invisible', $invisible);

  # Set flag in sub nodes
  $_->setAttribute('invisible', $invisible) foreach $mnode->getElementsByTagName('Message');

  return save_file($fname, \$xml->toString);
}

### modify_posting () ##########################################################
#
# Modify a posting (only subject and category until now!)
#
# Params: $forum  Path and filename of forum
#         $tpath  Path to thread files
#         \%info  Reference: 'thread', 'posting', 'indexFile', 'data'
#                 (data = \%hashref: 'subject', 'category', 'body')
# Return: -none-
#
# Todo:
#   * Lock files!
#   * save return values
#
sub modify_posting($$$) {
  my ($forum, $tpath, $info) = @_;
  my ($tid, $mid, $indexFile, $data) = (
    $info->{'thread'},
    $info->{'posting'},
    $info->{'indexFile'},
    $info->{'data'}
  );

  my ($subject, $category, $body) = (
    $data->{'subject'},
    $data->{'category'},
    $data->{'body'}
  );

  my %msgdata;

  # These values may be changed by change_posting_value()
  $msgdata{'Subject'} = $subject if $subject;
  $msgdata{'Category'} = $category if $category;

  # Thread
  my $tfile = $tpath . '/t' . $tid . '.xml';
  change_posting_value($tfile, 't'.$tid, 'm'.$mid, \%msgdata);
  change_posting_body($tfile, 't'.$tid, 'm'.$mid, $body) if $body;

  # Forum (does not contain msg bodies)
  if ($subject or $category) {
    my ($f, $lthread, $lmsg, $dtd, $zlev) = get_all_threads($forum, 1, 0);

    for (@{$f->{$tid}}) {
      if ($_->{'mid'} == $mid) {
        $_->{'subject'} = $subject if $subject;
        $_->{'cat'} = $category if $category;
      }
    }

   save_file($forum, create_forum_xml_string($f,{dtd=>$dtd,lastMessage=>$lmsg,lastThread$lthread}));
  }

}

### change_posting_value () ####################################################
#
# Change specific values of a posting
#
# Params: $fname    Filename
#         $tid      Thread ID
#         $mid      Message ID
#         \%values  New values
# Return: Status code
#
sub change_posting_value($$$$) {
  my ($fname, $tid, $mid, $values) = @_;

  my $xml   = parse_xml_file($fname);
  my $mnode = get_message_node($xml, $tid, $mid);

  for (keys %$values) {
    # Find first direct child node with name $_
    my $nodes = $mnode->getElementsByTagName($_, 0);
    my $node = $nodes->item(0);
    $node->setValue($values->{$_});
  }

  return save_file($fname, \$xml->toString);
}

### change_posting_body () #####################################################
#
# Change body of a posting
#
# Params: $fname  Filename
#         $tid    Thread ID (unused, for compatibility purposes)
#         $mid    Message ID
#         $body   New body
# Return: Status code
#
# Todo:
#  * Change body
#
sub change_posting_body ($$$$) {
  my ($fname, $tid, $mid, $body) = @_;

  my $xml    = parse_xml_file($fname);
  my $mbnody = get_message_body($xml, $mid);

    # todo: change body

  return save_file($fname, \$xml->toString);
}


# Let it be true
1;

#
#
### end of Posting::Admin ######################################################
