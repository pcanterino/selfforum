package Conf::Admin;

################################################################################
#                                                                              #
# File:        shared/CheckRFC.pm                                              #
#                                                                              #
# Authors:     Andre Malo       <nd@o3media.de>, 2001-06-16                    #
#                                                                              #
# Description: read and parse admin default config                             #
#                                                                              #
################################################################################

use strict;
use vars qw(
  @EXPORT
  $VERSION
);

use Lock;

use XML::DOM;

################################################################################
#
# Version check
#
$VERSION = do { my @r =(q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

################################################################################
#
# Export
#
use base qw(Exporter);
@EXPORT = qw(read_admin_conf);

### get_severance () ###########################################################
#
# read out severance config (used twice)
#
# Params: $severance - element node
#
# Return: hashref
#
sub get_severance ($) {
  my $severance = shift;

  my $after_byte    = $severance -> getElementsByTagName ('AfterByte', 0) -> item (0);
  my $after_message = $severance -> getElementsByTagName ('AfterMessage', 0) -> item (0);
  my $after_thread  = $severance -> getElementsByTagName ('AfterThread', 0) -> item (0);
  my $last_posting  = $severance -> getElementsByTagName ('AfterLastPosting', 0) -> item (0);

  my %conf =(
    exArchiving  => $severance -> getAttribute ('executeArchiving'),
    archiving    => $severance
      -> getElementsByTagName ('Archiving', 0) -> item (0)
      -> getElementsByTagName ('*', 0) -> item (0) -> getTagName,
    severance    => $severance -> getAttribute ('executeSeverance'),
    afterByte    => (
      $after_byte
      ? $after_byte -> getFirstChild -> getData
      : undef
    ),
    afterThread  => (
      $after_thread
      ? $after_thread -> getFirstChild -> getData
      : undef
    ),
    afterMessage => (
      $after_message
      ? $after_message -> getFirstChild -> getData
      : undef
    ),
    lastPosting  => (
      $last_posting
      ? $last_posting -> getFirstChild -> getData
      : undef
    )
  );

  \%conf;
}

### read_admin_conf () #########################################################
#
# read and parse admin config
#
# Params: $filename - filename
#
# Return: hashref
#
sub read_admin_conf ($) {
  my $filename=shift;
  my %conf;

  if (-f $filename) {
    my $admin = new Lock ($filename);
    if ($admin -> lock(LH_SHARED)) {
      my $xml = new XML::DOM::Parser -> parsefile ($admin -> filename);
      $admin -> unlock;

      # write data into the hash
      #
      my $forum = $xml -> getElementsByTagName ('Forum',0) -> item (0);

      # View
      my $forum_view      = $forum       -> getElementsByTagName ('ForumView', 0) -> item (0);
        my $thread_view   = $forum_view  -> getElementsByTagName ('ThreadView', 0) -> item (0);
          my $show_thread = $thread_view -> getElementsByTagName ('ShowThread', 0) -> item (0);
            my $show_how  = $show_thread -> getElementsByTagName ('*', 0) -> item (0);
            my $how_name  = $show_how -> getTagName;
        my $message_view  = $forum_view  -> getElementsByTagName ('MessageView', 0) -> item (0);
        my $flags         = $forum_view  -> getElementsByTagName ('Flags', 0) -> item (0);
        my $quoting       = $forum_view  -> getElementsByTagName ('Quoting', 0) -> item (0);
          my $char        = $quoting     -> getElementsByTagName ('Chars', 0) -> item (0);

      $conf {View} = {
        threadOpen    => $thread_view -> getAttribute ('threadOpen'),
        countMessages => $thread_view -> getAttribute ('countMessages'),
        sortThreads   => $thread_view -> getAttribute ('sortThreads'),
        sortMessages  => $thread_view -> getAttribute ('sortMessages'),
        showThread    => (($how_name eq 'ShowAll')
                         ? undef
                         : (($how_name eq 'ShowNone')
                           ? 1
                           : ($show_how -> getFirstChild -> getData))),
        showPreview   => $message_view -> getAttribute ('previewON'),
        showNA        => $flags -> getAttribute ('showNA'),
        showHQ        => $flags -> getAttribute ('showHQ'),
        quoting       => $quoting -> getAttribute ('quotingON'),
        quoteChars    => $char?$char -> getFirstChild -> getData:undef
      };

      my $voting = $forum -> getElementsByTagName ('Voting', 0) -> item (0);
      $conf {Voting} = {
        voteLock => $voting -> getAttribute ('voteLock'),
        Limit    => $voting -> getAttribute ('Limit')
      };

      # Severance
      $conf {Severance} = get_severance ($forum -> getElementsByTagName ('Severance', 0) -> item (0));

      # Messaging
      my $messaging      = $forum     -> getElementsByTagName ('Messaging', 0) -> item (0);
        my $call_by_user = $messaging -> getElementsByTagName ('CallByUser', 0) -> item (0);

      $conf {Messaging} = {
        userAnswer => $messaging -> getAttribute ('callUserAnswer'),
        thread     => $messaging -> getAttribute ('callAdminThread'),
        na         => $messaging -> getAttribute ('callAdminNA'),
        hq         => $messaging -> getAttribute ('callAdminHQ'),
        voting     => $messaging -> getAttribute ('callAdminVoting'),
        archiving  => $messaging -> getAttribute ('callAdminArchiving'),
        byUser     => $messaging -> getAttribute ('callUserAnswer'),
        callByName => [
          $call_by_user
          ? map {$_ -> getFirstChild -> getData} $call_by_user -> getElementsByTagName ('Name', 0)
          : ()
        ],
        callByMail => [
          $call_by_user
          ? map {$_ -> getFirstChild -> getData} $call_by_user -> getElementsByTagName ('Email', 0)
          : ()
        ],
        callByIP   => [
          $call_by_user
          ? map {$_ -> getFirstChild -> getData} $call_by_user -> getElementsByTagName ('IpAddress', 0)
          : ()
        ]
      };

      # Instant
      my $instant    = $forum   -> getElementsByTagName ('InstantJob', 0) -> item (0);
        my $job      = $instant -> getElementsByTagName ('*',0) -> item (0);
        my $job_name = $job -> getTagName;
        $job_name = $job -> getAttribute ('reason') if ($job_name ne 'Severance');

      $conf {Instant} = {
        execute     => $instant -> getAttribute ('executeJob'),
        description => $job_name,
        url         => (
          ($job_name ne 'Severance')
          ? $job -> getElementsByTagName ('FileUrl', 0) -> item (0) -> getFirstChild -> getData
          : undef
        ),
        Severance   => (
          ($job_name eq 'Severance')
          ? get_severance ($job)
          : undef
        )
      };

      # User
      my $user = $forum -> getElementsByTagName ('UserManagement', 0) -> item (0);

      $conf {User} = {
        deleteAfterDays => $user
          -> getElementsByTagName ('DeleteUser', 0) -> item (0)
          -> getElementsByTagName ('AfterDays', 0) -> item (0)
          -> getFirstChild -> getData
      };
    }
  }

  # return
  \%conf;
}

# keep 'require' happy
1;

#
#
### end of Conf::Admin #########################################################