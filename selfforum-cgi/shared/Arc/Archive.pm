package Arc::Archive;

################################################################################
#                                                                              #
# File:        shared/Arc/Archive.pm                                           #
#                                                                              #
# Authors:     Andre Malo       <nd@o3media.de>, 2001-06-16                    #
#                                                                              #
# Description: Severance of Threads and archiving                              #
#                                                                              #
################################################################################

use strict;
use vars qw(
  @EXPORT
  $VERSION
);

use Arc::Test;
use Lock          qw(:ALL);
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
@EXPORT = qw(cut_tail);

### sub cut_tail ($) ###########################################################
#
# shorten the main file and archive, if necessary
#
# Params: $param - hash reference
#                  (forumFile, messagePath, archivePath, lockFile, adminDefault,
#                   cachePath)
#
# Return: hash reference - empty if all right done
#
sub cut_tail ($) {
  my $param = shift;
  my %failed;

  if ( $param->{adminDefault}->{Severance}->{severance} ne 'instant'
    or $param->{adminDefault}->{Instant}->{execute}
  ) {
    if (write_lock_file($param->{lockFile}, 1)) {
      if (write_lock_file ($param->{forumFile})) {
        my (
          $threads,
          $last_thread,
          $last_message,
          $dtd,
          undef
        ) = get_all_threads ($param->{forumFile}, KEEP_DELETED);

        my $obsolete = get_obsolete_threads ({
          parsedThreads => $threads,
          adminDefault  => $param->{adminDefault}
        });

        delete $threads->{$_} for (@$obsolete);

        my $saved = save_file (
          $param -> {forumFile},
          create_forum_xml_string (
            $threads,
            { dtd         => $dtd,
              lastMessage => $last_message,
              lastThread  => $last_thread
            }
          )
        );
        if ($saved) {
          for (@$obsolete) {
            set_master_lock ($param->{messagePath}."t$_.xml") or $failed{$_} = 'could not set master lock';
          }
        }
        violent_unlock_file ($param->{forumFile}) unless (write_unlock_file ($param->{forumFile}));

        if ($saved) {
          # now process thread files
          #
          my $sev_opt = ($param -> {adminDefault} -> {Severance} -> {severance} eq 'instant')
            ? $param -> {adminDefault} -> {Instant} -> {Severance}
            : ($param -> {adminDefault} -> {Severance});

          my $cache = new Posting::Cache ($param->{cachePath});

          if ($sev_opt->{exArchiving}) {
            # yes, we cut & archive
            #
            my $sum = $cache -> summary;
            if ($sum) {
              for my $tid (grep {not exists ($failed{$_})} @$obsolete) {
                my $xml = parse_xml_file ($param->{messagePath}."t$tid.xml");
                unless ($xml) {
                  $failed{$tid} = 'could not parse thread file.';
                }
                else {
                  my $tnode = $xml -> getElementsByTagName ('Thread') -> item(0);
                  my $msg = parse_single_thread ($tnode, KEEP_DELETED);

                  if ($sev_opt->{archiving} eq 'UserVotings') {
                    # filter out the bad stuff
                    #
                    my $percent = $param->{adminDefault}->{Voting}->{Limit};
                    my ($oldlevel, @path, $z, %archive) = (0, 0);

                    for $z (0..$#{$msg}) {
                      if ($msg -> [$z] -> {level} > $oldlevel) {
                        push @path => $z;
                        $oldlevel = $msg -> [$z] -> {level};
                      }
                      elsif ($msg -> [$z] -> {level} < $oldlevel) {
                        splice @path, $msg -> [$z] -> {level};
                        push @path => $z;
                        $oldlevel = $msg -> [$z] -> {level};
                      }
                      else {
                        $path[-1] = $z;
                      }

                      if (defined $msg->[$z]->{archive}) {
                        if ($msg->[$z]->{archive}) {
                          $archive{$msg->[$_]->{mid}} = 1 for (@path);
                        }
                      }
                      unless ($msg->[$z]->{archive} or $msg->[$z]->{deleted}) {
                        my $key = $sum->{$tid}->{$msg->[$z]->{mid}};
                        if ($percent == 0 or ($key->{views} and ($key->{votings} * 100 / $key->{views}) >= $percent)) {
                          $archive{$msg->[$_]->{mid}} = 1 for (@path);
                        }
                      }
                    }

                    # now filter out
                    #
                    for (reverse grep {!$archive{$_->{mid}}} @$msg) {
                      my $h = get_message_node($xml, "t$tid", 'm'.$_->{mid});
                      $h -> getParentNode -> removeChild ($h);

                      $h = get_body_node($xml, 'm'.$_->{mid});
                      $h -> getParentNode -> removeChild ($h);
                    }
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

                      my ($month, $year) = (localtime ($msg->[0]->{time}))[4,5];
                      $month++; $year+=1900;
                      my $yeardir  = $param -> {archivePath} . $year;
                      my $yearpath = $yeardir . '/';
                      my $monthdir = $yearpath . $month;
                      my $monthpath = $monthdir . '/';
                      my $file = $monthpath . "t$tid.xml";

                      mkdir $yeardir unless (-d $yeardir);
                      if (-d $yeardir) {
                        mkdir $monthdir unless (-d $monthdir);
                        if (-d $monthdir) {
                          save_file (
                            $file,
                            \($xml -> toString)
                          ) or $failed{$tid} = "could not save '$file'";
                        }
                        else {
                          $failed{$tid} = "could not create directory '$monthdir'";
                        }
                      }
                      else {
                        $failed{$tid} = "could not create directory '$yeardir'";
                      }
                    }

                }
              }
            }
            else {
              @failed{@$obsolete} = 'could not load summary';
            }
          }
          # delete processed files
          #
          for (grep {not exists($failed{$_})} @$obsolete) {
            unlink ($param->{messagePath}."t$_.xml") or $failed{$_} = 'could not delete thread file';
            file_removed ($param->{messagePath}."t$_.xml");
          }
          $cache -> delete_threads (@$obsolete);
          $cache -> garbage_collection;
        }
      }
      else {
        violent_unlock_file ($param->{forumFile});
      }
      violent_unlock_file ($param->{lockFile}) unless (write_unlock_file ($param->{lockFile}));
    }
    else {
      violent_unlock_file ($param->{lockFile});
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