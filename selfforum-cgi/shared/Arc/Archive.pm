package Arc::Archive;

################################################################################
#                                                                              #
# File:        shared/Arc/Archive.pm                                           #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>                                      #
#                                                                              #
# Description: Severance of Threads and archiving                              #
#                                                                              #
################################################################################

use strict;
use vars qw(
  @EXPORT
);

use Arc::Test;
use Lock;
use Posting::_lib qw(
  get_all_threads
  create_forum_xml_string
  parse_xml_file
  parse_single_thread
  get_message_node
  get_body_node
  save_file
  KEEP_DELETED
);
use Posting::Cache;
use Time::German 'localtime';

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
@EXPORT = qw(cut_tail);

### delete_no_archived () ######################################################
#
# remove no archived branches vom thread
#
# Params: $xml     - XML::DOM::Document node
#         $msg     - arrayref - messages
#         $percent - voting limit (percent)
#
# Return: ~none~
#
sub delete_no_archived ($) {
  my $par = shift;

  my ($xml, $sum, $tid, $msg, $percent) = map {$par->{$_}}
   qw( xml   sum   tid   msg   percent);

  # $oldlevel: contains the level of last checked msg
  # @path    : contains the current branch
  # %archive : contains the mids, that will be archived
  # %hidden  : contains the invisible mids
  #
  my ($oldlevel, @path, %archive, %hidden) = (0, 0);

  # check all messages of thread
  #
  for my $z (0..$#{$msg}) {

    if ($msg -> [$z] -> {level} > $oldlevel) {
      # this msg is a child of the last one
      #
      push @path => $z;
      $oldlevel = $msg -> [$z] -> {level};
    }

    elsif ($msg -> [$z] -> {level} < $oldlevel) {
      # this starts a new subbranch (-1+ level(s))
      #

      # remove last msg (incl. kids), that is on same level
      #
      splice @path, $msg -> [$z] -> {level};
      push @path => $z;
      $oldlevel = $msg -> [$z] -> {level};
    }

    else {
      # the msg is a sister of the last one
      #
      $path[-1] = $z;
    }

    # 'archive' is an admin flag
    # if set, the message (incl. branch) MUST be archived
    #
    if (defined $msg->[$z]->{archive} and $msg->[$z]->{archive}) {
      $archive{$msg->[$_]->{mid}} = 1 for (@path);
    }

    # notice invisble messages
    # while they are in @path and archive flag is not set,
    # they and their kids WON'T be archived
    #
    $hidden{$z} = 1 if ($msg->[$z]->{deleted});

    # if 'archive' is NOT set and message not deleted,
    #
    unless ($msg->[$z]->{archive} or $msg->[$z]->{deleted}) {
      my $key = $sum->{$tid}->{$msg->[$z]->{mid}};

      # ...and they've voted enough, it will be archived
      #
      if ($percent == 0 or ($key->{views} and ($key->{votings} * 100 / $key->{views}) >= $percent)) {
        my $hidden_in_path;

        # check on hidden messages in @path
        #
        for (@path) {
          if ($hidden{$_}) {
            $hidden_in_path = 1;
            last;
          }
        }

        # set archive-flag for messages in @path,
        # unless a parent message is hidden
        #
        unless ($hidden_in_path) {
          $archive{$msg->[$_]->{mid}} = 1 for (@path);
        }
      }
    }
  }

  # now remove messages without 'archive'-flag
  # from thread xml
  #
  for (reverse grep {!$archive{$_->{mid}}} @$msg) {
    my $h = get_message_node($xml, "t$tid", 'm'.$_->{mid});

    # remove message entry
    #
    $h -> getParentNode -> removeChild ($h);

    # remove message text
    #
    $h = get_body_node($xml, 'm'.$_->{mid});
    $h -> getParentNode -> removeChild ($h);

    # 'remove' from $msg
    #
    $_->{deleted} = 1;
  }
}

### create_arcdir () ###########################################################
#
# check, if specific directories for year and month exist, create
# it, if necessary
#
# Params: $path - archive root
#         $time - Thread time (GMT)
#
# Return: List: $path  - /path/to/ to archived thread file
#               $error - error or undef
#
sub create_arcdir ($$) {
  my ($path, $time) = @_;

  my ($month, $year) = (localtime ($time))[4,5];

  # use the 'real' values for directory names
  #
  $month++; $year+=1900;

  my $yeardir   = $path     . $year;
  my $monthdir  = $yeardir  . '/' . $month;
  my $monthpath = $monthdir . '/';

  mkdir $yeardir, 0777 unless (-d $yeardir);
  return ('', "could not create directory '$yeardir'") unless (-d $yeardir);

  mkdir $monthdir, 0777 unless (-d $monthdir);
  return ('', "could not create directory '$monthdir'") unless (-d $monthdir);

  # return path, successfully created
  #
  $monthpath;
}

### process_threads () #########################################################
#
# process obsolete threads
# (transmit views/votings from cache, do archive, if necessary)
#
# Params: $par - hash reference
#                (opt, cache, failed, obsolete, messagePath,
#                 archivePath, adminDefault)
#
# Return: hashref (tid => $msg)
#
sub process_threads ($) {
  my $par = shift;

  my ($opt, $failed, $obsolete, $cache) = map {$par->{$_}} qw
     ( opt   failed   obsolete   cache);

  my %archived;

  if ($opt->{exArchiving}) {

    # yes, we do archive
    #
    my $sum = $cache -> summary;
    if ($sum) {

      # iterate over all obsolete threads, that are not failed yet
      #
      for my $tid (grep {not exists ($failed->{$_})} @$obsolete) {
        my $xml = parse_xml_file ($par->{messagePath}."t$tid.xml");

        unless ($xml) {
          # xml parse error
          #
          $failed->{$tid} = 'could not parse thread file.';
        }
        else {
          # ok, parse thread
          #
          my $tnode = $xml -> getElementsByTagName ('Thread') -> item(0);
          my $msg = parse_single_thread ($tnode, KEEP_DELETED);

          if ($opt->{archiving} eq 'UserVotings') {

            # filter out the bad stuff
            #
            delete_no_archived ({
              xml     => $xml,
              sum     => $sum,
              tid     => $tid,
              msg     => $msg,
              percent => $par->{adminDefault}->{Voting}->{Limit}
            });
          }

          # save back xml file (into archive)
          #
          if ($tnode -> hasChildNodes) {

            # insert views and votings counter
            #
            for ($tnode -> getElementsByTagName ('Message')) {
              my ($id) = $_ -> getAttribute ('id') =~ /(\d+)/;
              $_ -> setAttribute ('views'   => $sum->{$tid}->{$id}->{views});
              $_ -> setAttribute ('votings' => $sum->{$tid}->{$id}->{votings});
            }

            # create archive dir, unless exists
            #
            my ($path, $error) = create_arcdir ($par -> {archivePath}, $msg->[0]->{time});

            if ($error) {
              $failed->{$tid} = $error;
            }
            else {
              # save thread file
              #
              my $file = "${path}t$tid.xml";
              unless (save_file ($file => \($xml -> toString))) {
                $failed->{$tid} = "could not save '$file'";
              }
              else {
                $archived{$tid} = $msg
              }
            }
          }
        }
      }
    }
    else {
      @$failed{@$obsolete} = 'error: could not load summary';
    }
  }

  \%archived;
}

### append_threads () ##########################################################
#
# open specified index file, append threads, save it back
#
# Params: $file    - /path/to/indexfile
#         $threads - hashref (threads)
#
# Return: success code (boolean)
#
sub append_threads ($$) {
  my ($file, $threads) = @_;
  my $thash={};

  my $index = new Lock ($file);

  return unless ($index -> lock (LH_EXCL));

  if (-f $file) {
    $thash = get_all_threads ($file => KEEP_DELETED);
    $thash->{$_} = $threads->{$_} for (keys %$threads);
  }
  else {
    $thash = $threads;
  }

  # save it back...
  #
  my $saved = save_file (
    $file => create_forum_xml_string (
      $thash,
      {
        dtd         => 'forum.dtd',
        lastMessage => 0,
        lastThread  => 0
      }
    )
  );

  $index -> unlock;

  return unless $saved;

  1;
}

### indexpath () ###############################################################
#
# compose relative path of archive index file
#
# Params: $param - hash reference
#                  ($msg->[0])
#
# Return: $string (relative path)
#
sub indexpath ($) {
  my $root = shift;

  my ($month, $year) = (localtime ($root->{time}))[4,5];

  # use the 'real' values for directory names
  #
  $month++; $year+=1900;

  "$year/$month/";
}

### index_threads () ###########################################################
#
# add threads to their specific archive index file
#
# Params: $param - hash reference
#                  (threads, archivePath, archiveIndex, failed)
#
# Return: ~none~
#
sub index_threads ($) {
  my $par = shift;

  my ($threads, $failed) = map {$par->{$_}} qw
     ( threads   failed);

  # indexfile => hashref of threads
  # for more efficiency (open each index file *once*)
  #
  my %index;

  # iterate over all archived threads,
  # prepare indexing and assign threads to indexfiles
  #
  for my $thread (keys %$threads) {

    # index only, if the root is visible
    #
    unless ($threads->{$thread}->[0]->{deleted}) {
      my $file = $par->{archivePath} . indexpath ($threads->{$thread}->[0]) . $par->{archiveIndex};
      $index{$file} = {} unless exists($index{$file});

      $index{$file} -> {$thread} = [$threads->{$thread}->[0]];
    }
  }

  # now append threads to index files
  #
  for my $file (keys %index) {
    unless (append_threads ($file => $index{$file})) {
      $failed->{$_} = "error: could not list in '$file'" for (keys %{$index{$file}});
    }
  }
}

### cut_tail () ################################################################
#
# shorten the main file and archive, if necessary
#
# Params: $param - hash reference
#                  (forumFile, messagePath, archivePath, lockFile, adminDefault,
#                   cachePath, archiveIndex)
#
# Return: hash reference - empty if all right done
#
sub cut_tail ($) {
  my $param = shift;
  my %failed;

  if (
    $param->{adminDefault}->{Severance}->{severance} ne 'instant' or
    $param->{adminDefault}->{Instant}->{execute}
  ) {
    # run only one instance at the same time
    # (exlusive lock on sev_lock)
    #
    my $sev = new Lock ($param->{lockFile});
    if ($sev -> lock(LH_EXCL)) {

      # lock and parse forum main file
      #
      my $forum = new Lock ($param->{forumFile});
      if ($forum -> lock (LH_EXCL)) {
        my (
          $threads,
          $last_thread,
          $last_message,
          $dtd
        ) = get_all_threads ($forum->filename, KEEP_DELETED);

        # get obsolete threads...
        #
        my $obsolete = get_obsolete_threads ({
          parsedThreads => $threads,
          adminDefault  => $param->{adminDefault}
        });

        unless (@$obsolete) {
          # nothing to cut - we're ready
          #
          $forum -> unlock;
        }
        else {
          # ...and delete them from main
          #
          my %obsolete;
          for (@$obsolete) {
            $obsolete{$_} = $threads->{$_};
            delete $threads->{$_};
          }

          # save it back...
          #
          my $saved = save_file (
            $param -> {forumFile},
            create_forum_xml_string (
              $threads,
              {
                dtd         => $dtd,
                lastMessage => $last_message,
                lastThread  => $last_thread
              }
            )
          );

          # ...and masterlock the obsolete thread files
          #
          if ($saved) {
            for (@$obsolete) {
              new Lock($param->{messagePath}."t$_.xml")->lock(LH_MASTER) or $failed{$_} = 'error: could not set master lock';
            }
          }

          # release forum main file...
          #
          $forum -> unlock;

          if ($saved) {
            # ...and now process thread files
            #
            my $sev_opt = ($param -> {adminDefault} -> {Severance} -> {severance} eq 'instant')
               ? $param -> {adminDefault} -> {Instant} -> {Severance}
               : ($param -> {adminDefault} -> {Severance});

            my $cache = new Posting::Cache ($param->{cachePath});

            process_threads ({
              opt          => $sev_opt,
              cache        => $cache,
              failed       => \%failed,
              obsolete     => $obsolete,
              messagePath  => $param->{messagePath},
              archivePath  => $param->{archivePath},
              adminDefault => $param->{adminDefault}
            });

            # delete processed files, that are not failed
            #
            my @removed;

            for (grep {not exists($failed{$_})} @$obsolete) {
              if (exists($failed{$_})) {
                delete $obsolete{$_};
              }
              else {
                my $tfile = new Lock ($param->{messagePath}."t$_.xml");
                unless (unlink ($tfile->filename)) {
                  $failed{$_} = 'warning: could not delete thread file';
                }
                else {
                  push @removed => $_;
                  $tfile -> purge;
                }
              }
            }

            if (@removed) {
              $cache -> delete_threads (@removed);
              $cache -> garbage_collection;
            }

            # add archived threads to archive index
            #
            index_threads ({
              threads      => \%obsolete,
              archivePath  => $param->{archivePath},
              archiveIndex => $param->{archiveIndex},
              failed       => \%failed
            });
          }
        }

        # we're ready, tell this other (waiting?) instances
        #
        $sev -> unlock;
      }
    }
  }

  # return
  \%failed;
}

# keep 'require' happy
1;

#
#
### end of Arc::Archive ########################################################