package Posting::Cache;

################################################################################
#                                                                              #
# File:        shared/Posting/Cache.pm                                         #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>, 2001-04-21                          #
#                                                                              #
# Description: Views/Voting Cache class                                        #
#                                                                              #
################################################################################

use strict;

use Fcntl;
use Lock qw(:ALL);

my $O_BINARY = eval "O_BINARY";
$O_BINARY = 0 if ($@);

### sub new ####################################################################
#
# Constructor
#
# Params: $filename - full qualified cache file name
#
# Return: Posting::Cache object
#
sub new {
  my $self = bless {} => shift;

  $self -> clear_error;
  $self -> set_file (+shift);

  $self -> repair_cache or do {
    $self -> set_error ('cache '.$self->cachefile.' is broken and not repairable.')
  };

  $self;
}

### sub clear_error ############################################################
#
# clear verbal error data
#
# Params: ~none~
#
# Return: ~none~
#
sub clear_error {
  my $self = shift;

  $self -> {verb_error} = undef;

  return;
}

sub error {$_[0]->{verb_error}}

sub set_error {
  my $self = shift;

  $self -> {verb_error} = +shift;

  return;
}

### sub set_file ###############################################################
#
# set cache file name
#
# Params: $filename - full qualified cache file name
#
sub set_file {
  my ($self, $filename) = @_;

  $self -> {cachefile} = $filename;

  return;
}

sub cachefile {$_[0] -> {cachefile}}
sub indexfile {$_[0] -> cachefile . '.index'}
sub temp_cachefile {$_[0] -> cachefile . '.temp'}
sub temp_indexfile {$_[0] -> indexfile . '.temp'}

### sub find_pos ($$) ##########################################################
#
# find position in cache file
# (binary search in index file)
#
# Params: $handle  - index file handle
#         $posting - posting number
#
# Return: position or false (undef)
#
sub find_pos ($$) {
  my ($I, $posting) = @_;
  my $reclen = 2 * length pack 'L',0;
  my $end = (-s $I) / $reclen;

  $end == int $end                                         or return;

  my ($start, $buf, $current) = 0;

  while ($start <= $end) {
    seek $I, ($current = ($start + $end) >> 1)*$reclen, 0  or return;
    $reclen == read ($I, $buf, $reclen)                    or return;

    my ($num, $found) = unpack 'L2',$buf;

    if ($num == $posting) {
      return $found;
    }
    elsif ($num < $posting) {
      $start = $current+1
    }
    else {
      $end   = $current-1
    }
  }

  return;
}

### sub add_view ###############################################################
#
# increment the views-counter
#
# Params: ~none~
#
# Return: Status code (Bool)
#
sub r_add_view {
  my ($self, $h, $param) = @_;
  my ($C, $I) = ($h->{C}, $h->{I});
  my $reclen  = 4 * length pack 'L', 0;
  my $pos;
  defined ($pos = find_pos $I, $param->{posting})                or return;

  my $buf;
  seek $C, $pos, 0                                               or return;
  read ($C, $buf, $reclen) == $reclen                            or return;

  my ($posting, $thread, $views, $votings) = unpack 'L4',$buf;
  $thread == $param->{thread}                                    or return;
  seek $C, $pos, 0                                               or return;
  print $C pack ('L4' => $posting, $thread, $views+1, $votings)  or return;

  1;
}

sub add_view {
  my ($self, $param) = @_;

  $self -> write_wrap (
    \&r_add_view,
    $param
  );
}

### sub pick ###################################################################
#
# read information of one posting
#
# Params: $param - hash reference
#                  (thread, posting)
#
# Return: hash reference or false
#
sub r_pick {
  my ($self, $h, $param) = @_;
  my ($C, $I) = ($h->{C}, $h->{I});
  my $reclen  = 4 * length pack 'L', 0;
  my ($buf, $pos);
  local $/="\012";

  defined($pos = find_pos $I, $param->{posting})      or return;

  seek $C, $pos, 0                                    or return;
  read ($C, $buf, $reclen) == $reclen                 or return;

  my ($posting, $thread, $views, $votings) = unpack 'L4', $buf;
  $buf = <$C>; chomp $buf;
  $self -> {pick} = {
    views   => $views,
    votings => $votings,
    voteRef  => {
      map {
        map {
          $_->[2] => {
            time => $_->[0] || 0,
            IP   => $_->[1] || 0
          }
        } [split /;/]
      } split ' ' => $buf
    }
  };

  # looks good
  1;
}

sub pick {
  my ($self, $param) = @_;

  $self -> read_wrap (\&r_pick, $param)
    ? $self -> {pick}
    : return;
}

### sub summary ################################################################
#
# read out the cache and return a summary
#
# Params: ~none~
#
# Return: hash reference or false
#
sub r_summary {
  my ($self, $h) = @_;
  my ($C, $I) = ($h->{C}, $h->{I});
  my $reclen  = length pack 'L', 0;
  my $ireclen = 2 * $reclen;
  my $creclen = 4 * $reclen;
  my ($buf, $pos, %hash);


  while ($ireclen == read ($I, $buf, $ireclen)) {
    (undef, $pos) = unpack 'L2', $buf;

    seek $C, $pos, 0                                 or return;
    read ($C, $buf, $creclen) == $creclen            or return;

    my ($posting, $thread, $views, $votings) = unpack 'L4', $buf;
    $hash{$thread} = {} unless $hash{$thread};
    $hash{$thread} -> {$posting} = {
      views   => $views,
      votings => $votings
    };
  }

  $self -> {summary} = \%hash;

  # looks good
  1;
}

sub summary {
  my $self = shift;

  $self -> read_wrap (\&r_summary)
    ? $self -> {summary}
    : return;
}

### sub repair_cache ###########################################################
#
# check on cache consistance and repair if broken
#
# Params: ~none~
#
# Return: sucess code (Bool)
#
sub r_repair_cache {
  my ($self, $h) = @_;
  my ($C, $TC, $TI) = ($h->{C}, $h->{TC}, $h->{TI});
  my $pos = tell $TC;
  my ($block);
  my $reclen = 4 * length pack 'L',0;
  local $/="\012";
  local $\;

  while ($reclen == read $C, $block, $reclen) {
    my $msg = unpack ('L' => $block);
    my $rest = <$C>;
    chomp $rest;
    print $TC $block. $rest. $/;
    print $TI pack ('L2' => $msg, $pos);
    $pos = tell $TC;
  }

  1;
}

sub repair_cache {
  my $self = shift;

  return unless ($self->cachefile and $self->indexfile);
  return 1 if (-f $self->cachefile and -f $self->indexfile);

  unless (-f $self->cachefile) {
    return if (-f $self->indexfile);

    local *FILE;
    return unless (open FILE, '>'.$self->cachefile);
    return unless (close FILE);
    return unless (open FILE, '>'.$self->indexfile);
    return unless (close FILE);

    release_file ($self->cachefile);
    release_file ($self->indexfile);
    release_file ($self->temp_indexfile);
    release_file ($self->temp_cachefile);

    return 1;
  }

  $self -> open_wrap (\&r_repair_cache);
}

### sub add_posting ############################################################
#
# add an empty cache entry of a posting
#
# Params: $param - hash reference
#                  (thread, posting)
#
# Return: Status code (Bool)
#
sub r_add_posting {
  my ($self, $h, $param) = @_;
  my ($C, $TC, $TI) = ($h->{C}, $h->{TC}, $h->{TI});
  my $pos = tell $TC;
  my ($block, $ins, $msg);
  my $reclen = 4 * length pack 'L',0;
  local $/="\012";
  local $\;

  while ($reclen == read $C, $block, $reclen) {
    $msg = unpack ('L' => $block);

    if ($param -> {posting} == $msg) {
      $self->set_error("double defined posting id 'm$msg'");
      return;
    };
    next if ($param -> {posting} > $msg or $ins);

    print $TC pack('L4' => $param->{posting}, $param->{thread}, 0, 0), $/;
    print $TI pack('L2' => $param->{posting}, $pos);
    $pos = tell $TC;
    $ins = 1;
  }
  continue {
    my $rest = <$C>;
    chomp $rest;
    print $TC $block. $rest. $/;
    print $TI pack ('L2' => $msg, $pos);
    $pos = tell $TC;
  }
  unless ($ins) {
    print $TC pack('L4' => $param->{posting}, $param->{thread}, 0, 0), $/;
    print $TI pack('L2' => $param->{posting}, $pos);
  }

  1;
}

sub add_posting {
  my $self = shift;
  $self -> open_wrap (
    \&r_add_posting,
    @_
  );
}

### sub add_voting #############################################################
#
# add a voting (increment vote counter and log the vote data)
#
# Params: $param - hash reference
#                  (thread, posting, IP, time, ID)
#
# Return: Status code (Bool)
#
sub r_add_voting {
  my ($self, $h, $param) = @_;
  my ($C, $TC, $TI) = ($h->{C}, $h->{TC}, $h->{TI});
  my $pos = tell $TC;
  my $block;
  my $reclen = 4 * length pack 'L',0;
  local $/="\012";
  local $\;

  while ($reclen == read $C, $block, $reclen) {
    my $rest = <$C>;
    chomp $rest;
    my ($msg, $thread, $views, $votings) = unpack ('L4' => $block);

    $param -> {posting} != $msg or do {
      $rest = join ' ' => (length $rest ? $rest: (), join ';' => ($param->{time}, $param->{IP}, $param->{ID}));
      $votings++;
    };

    print $TC pack ('L4' => ($msg, $thread, $views, $votings)), $rest, $/;
    print $TI pack ('L2' => $msg, $pos);
    $pos = tell $TC;
  }

  1;
}

sub add_voting {
  my $self = shift;
  $self -> open_wrap (
    \&r_add_voting,
    @_
  );
}

### sub open_wrap ##############################################################
#
# file lock, open, execute, close, unlock wrapper
# for writing into temp files
#
# Params: $gosub - sub reference (for execution)
#         @param - params (for $gosub)
#
# Return: Status code (Bool)
#
sub open_wrap {
  my ($self, $gosub, @param) = @_;
  my $status;

  unless (write_lock_file ($self->temp_cachefile)) {
    violent_unlock_file ($self->temp_cachefile);
    $self->set_error ('could not write-lock temp cache file '.$self->temp_cachefile);
  }
  else {
    unless (write_lock_file ($self->temp_indexfile)) {
      violent_unlock_file ($self->temp_indexfile);
      $self->set_error ('could not write-lock temp index file '.$self->temp_indexfile);
    }
    else {
      unless (lock_file ($self->cachefile)) {
        violent_unlock_file ($self->cachefile);
        $self->set_error ('could not read-lock cache file '.$self->cachefile);
      }
      else {
        unless (lock_file ($self->indexfile)) {
          violent_unlock_file ($self->indexfile);
          $self->set_error ('could not read-lock index file '.$self->indexfile);
        }
        else {
          local (*C, *TC, *TI);
          unless (sysopen (C, $self->cachefile, O_RDONLY | $O_BINARY)) {
            $self->set_error ('could not open to read cache file '.$self->cachefile);
          }
          else {
            unless (sysopen (TC, $self->temp_cachefile, O_WRONLY | O_TRUNC | O_CREAT | $O_BINARY)) {
              $self->set_error ('could not open to write temp cache file '.$self->temp_cachefile);
            }
            else {
              unless (sysopen (TI, $self->temp_indexfile, O_WRONLY | O_TRUNC | O_CREAT | $O_BINARY)) {
                $self->set_error ('could not open to write temp index file '.$self->temp_indexfile);
              }
              else {
                $status = $gosub -> (
                  $self,
                  { C  => \*C,
                    TC => \*TC,
                    TI => \*TI
                  },
                  @param
                );
                unless (close TI) {
                  $status=0;
                  $self->set_error('could not close temp index file '.$self->temp_indexfile);
                }
              }
              unless (close TC) {
                $status=0;
                $self->set_error('could not close temp cache file '.$self->temp_cachefile);
              }
            }
            unless (close C) {
              $status=0;
              $self->set_error('could not close cache file '.$self->cachefile);
            }
            if ($status) {
              unless (write_lock_file ($self->cachefile) and write_lock_file ($self->indexfile)) {
                $status=0;
                $self->set_error('could not write-lock cache or index file');
              }
              else {
                unless (unlink $self->indexfile or !-f $self->indexfile) {
                  $status=0;
                  $self->set_error('could not unlink '.$self->indexfile);
                }
                else {
                  unless (rename $self->temp_cachefile => $self->cachefile) {
                    $status=0;
                    $self->set_error('could not rename '.$self->temp_cachefile);
                  }
                  else {
                    unless (rename $self->temp_indexfile => $self->indexfile) {
                      $status=0;
                      $self->set_error('could not rename '.$self->temp_indexfile);
                    }
                  }
                }
              }
            }
          }
          violent_unlock_file ($self->indexfile) unless (unlock_file ($self->indexfile));
        }
        violent_unlock_file ($self->cachefile) unless (unlock_file ($self->cachefile));
      }
      violent_unlock_file ($self->temp_indexfile) unless (write_unlock_file ($self->temp_indexfile));
    }
    violent_unlock_file ($self->temp_cachefile) unless (write_unlock_file ($self->temp_cachefile));
  }

  # return
  $status;
}

### sub read_wrap ##############################################################
#
# file lock, open, execute, close, unlock wrapper
# for reading
#
# Params: $gosub - sub reference (for execution)
#         @param - params (for $gosub)
#
# Return: Status code (Bool)
#
sub read_wrap {
  my ($self, $gosub, @param) = @_;
  my $status;

  unless (lock_file ($self->cachefile)) {
    violent_unlock_file ($self->cachefile);
    $self->set_error ('could not read-lock cache file '.$self->cachefile);
  }
  else {
    unless (lock_file ($self->indexfile)) {
      violent_unlock_file ($self->indexfile);
      $self->set_error ('could not read-lock index file '.$self->indexfile);
    }
    else {
      local (*C, *I);
      unless (sysopen (C, $self->cachefile, O_RDONLY | $O_BINARY)) {
        $self->set_error ('could not open to read cache file '.$self->cachefile);
      }
      else {
        unless (sysopen (I, $self->indexfile, O_RDONLY | $O_BINARY)) {
          $self->set_error ('could not open to read index file '.$self->indexfile);
        }
        else {
          $status = $gosub -> (
            $self,
            { C  => \*C,
              I => \*I,
            },
            @param
          );
          unless (close I) {
            $status=0;
            $self->set_error('could not close index file '.$self->indexfile);
          }
        }
        unless (close C) {
          $status=0;
          $self->set_error('could not close cache file '.$self->cachefile);
        }
      }
      violent_unlock_file ($self->indexfile) unless (unlock_file ($self->indexfile));
    }
    violent_unlock_file ($self->cachefile) unless (unlock_file ($self->cachefile));
  }

  # return
  $status;
}

### sub write_wrap ##############################################################
#
# file lock, open, execute, close, unlock wrapper
# for reading
#
# Params: $gosub - sub reference (for execution)
#         @param - params (for $gosub)
#
# Return: Status code (Bool)
#
sub write_wrap {
  my ($self, $gosub, @param) = @_;
  my $status;

  unless (write_lock_file ($self->temp_cachefile)) {
    violent_unlock_file ($self->temp_cachefile);
    $self->set_error ('could not write-lock temp cache file '.$self->temp_cachefile);
  }
  else {
    unless (write_lock_file ($self->cachefile)) {
      violent_unlock_file ($self->cachefile);
      $self->set_error ('could not write-lock cache file '.$self->cachefile);
    }
    else {
      unless (lock_file ($self->indexfile)) {
        violent_unlock_file ($self->indexfile);
        $self->set_error ('could not read-lock index file '.$self->indexfile);
      }
      else {
        local (*C, *I);
        unless (sysopen (C, $self->cachefile, O_RDWR | $O_BINARY)) {
          $self->set_error ('could not open to read/write cache file '.$self->cachefile);
        }
        else {
          unless (sysopen (I, $self->indexfile, O_RDONLY | $O_BINARY)) {
            $self->set_error ('could not open to read index file '.$self->indexfile);
          }
          else {
            $status = $gosub -> (
              $self,
              { C  => \*C,
                I => \*I,
              },
              @param
            );
            unless (close I) {
              $status=0;
              $self->set_error('could not close index file '.$self->indexfile);
            }
          }
          unless (close C) {
            $status=0;
            $self->set_error('could not close cache file '.$self->cachefile);
          }
        }
        violent_unlock_file ($self->indexfile) unless (unlock_file ($self->indexfile));
      }
      violent_unlock_file ($self->cachefile) unless (write_unlock_file ($self->cachefile));
    }
    violent_unlock_file ($self->temp_cachefile) unless (write_unlock_file ($self->temp_cachefile));
  }

  # return
  $status;
}

# keep 'require' happy
#
1;

#
#
### end of Posting::Cache ######################################################