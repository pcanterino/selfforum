package Posting::Cache;

################################################################################
#                                                                              #
# File:        shared/Posting/Cache.pm                                         #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>                                      #
#                                                                              #
# Description: Views/Voting Cache class                                        #
#                                                                              #
################################################################################

use strict;
use Fcntl;
use File::Path;
use Lock;

################################################################################
#
# Version check
#
# last modified:
#    $Date$ (GMT)
# by $Author$
#
sub VERSION {(q$Revision$ =~ /([\d.]+)\s*$/)[0] or '0.0'}

my $O_BINARY = eval q{
  local $SIG{__DIE__};
  O_BINARY;
};
$O_BINARY = 0 if ($@);

### sub new ####################################################################
#
# Constructor
#
# Params: $pathname - full qualified cache path
#
# Return: Posting::Cache object
#
sub new {
  my $self = bless {} => shift;

  $self -> clear_error;
  $self -> set_path (+shift);

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

### sub set_path ###############################################################
#
# set cache file name
#
# Params: $pathname - full qualified cache path
#
sub set_path {
  my ($self, $pathname) = @_;

  $self -> {cachepath} = $pathname;

  return;
}

sub cachepath   {$_[0] -> {cachepath}}
sub threaddir   {$_[0] -> cachepath          . $_[1] -> {thread}}
sub threadpath  {$_[0] -> threaddir  ($_[1]) . '/'}
sub cachefile   {$_[0] -> threadpath ($_[1]) . $_[1] -> {posting} . '.txt'}
sub summaryfile {$_[0] -> cachepath          . 'summary.bin'}

### sub delete_threads #########################################################
#
# remove threads from cache
#
# Params: @threads - list of threadnumbers
#
# Return: Status Code (Bool)
#
sub delete_threads {
  my ($self, @threads) = @_;
  my %threads = map {$_ => 1} @threads;

  $self -> mod_wrap (
    \&r_delete_threads,
    \%threads
  );
}
sub r_delete_threads {
  my ($self, $handle, $threads) = @_;
  my $l = length (pack 'L' => 0);
  my $reclen = $l << 2;
  my $len = -s $handle;
  my $num = int ($len / $reclen) -1;
  my ($buf, %hash);
  local $/;
  local $\;

  for (0..$num) {
    seek $handle, $_ * $reclen + $l, 0                 or return;
    read ($handle, $buf, $l) == $l                     or return;
    if ($threads->{unpack 'L' => $buf}) {
      seek $handle, $_ * $reclen + $l, 0               or return;
      print $handle pack ('L' => 0)                    or return;
    }
  }

  rmtree ($self->threaddir({thread => $_}), 0, 0)
    for (keys %$threads);

  1;
}

### sub garbage_collection #####################################################
#
# remove old entrys from the beginning of the cache
#
# Params: ~none~
#
# Return: ~none~
#
sub garbage_collection {
  my $self = shift;

  $self -> purge_wrap (
    \&r_garbage_collection
  );
}
sub r_garbage_collection {
  my ($self, $handle, $file) = @_;

  my $reclen  = length (pack 'L', 0) << 2;
  my $len = -s $handle;
  my $num = int ($len / $reclen) -1;
  my ($z, $buf, $h) = 0;
  local $/;
  local $\;

  return; # no GC yet

  seek $handle, 0, 0                                 or return;
  read ($handle, $buf, $len)                         or return;
  for (0..$num) {
    (undef, $h) = (unpack 'L2' => substr ($buf, $_ * $reclen, $reclen));
    last if $h;
    return unless (defined $h);
    $z++;
  }
  substr ($buf, 0, $z * $reclen) = '';

  seek $file, 0, 0                                   or return;
  print $file $buf                                   or return;

  # looks good
  1;
}

### sub find_pos ($$) ##########################################################
#
# find position in cache file
#
# Params: $handle  - summary file handle
#         $posting - posting number
#
# Return: position or false (undef)
#
sub find_pos ($$) {
  my ($handle, $posting) = @_;
  my $reclen = length (pack 'L',0);
  my $lreclen = $reclen << 2;
  seek $handle, 0, 0                                       or return;

  my $buf;
  read ($handle, $buf, $reclen) == $reclen                 or return;

  my $first = unpack ('L' => $buf);
  $first <= $posting                                       or return;

  my $pos = ($posting - $first) * $lreclen;
  seek $handle, $pos, 0                                    or return;

  $pos;
}

### sub add_view ###############################################################
#
# increment the views-counter
#
# Params: hash reference
#         (posting, thread)
#
# Return: Status code (Bool)
#
sub add_view {
  my ($self, $param) = @_;

  $self -> mod_wrap (
    \&r_add_view,
    $param
  );
}
sub r_add_view {
  my ($self, $handle, $param) = @_;
  my $reclen  = length (pack 'L', 0) << 2;
  my $pos;
  defined ($pos = find_pos $handle, $param->{posting})                or return;

  my $buf;
  seek $handle, $pos, 0                                               or return;
  read ($handle, $buf, $reclen) == $reclen                            or return;

  my ($posting, $thread, $views, $votings) = unpack 'L4' => $buf;
  $thread == 0xFFFFFFFF and $thread = $param->{thread};

  $param->{thread} == $thread                                         or return;
  $param->{posting} == $posting                                       or return;

  seek $handle, $pos, 0                                               or return;

  local $\;
  print $handle pack ('L4' => $posting, $thread, $views+1, $votings)  or return;

  1;
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
sub pick {
  my ($self, $param) = @_;

  $self -> pick_wrap (
    \&r_pick,
    $self->cachefile($param),
    $param
  ) ? $self -> {pick}
    : return;
}
sub r_pick {
  my ($self, $handle, $file, $param) = @_;
  my $reclen  = 4 * length (pack 'L' => 0);
  my ($buf, $pos);
  local $/="\n";

  defined($pos = find_pos $handle, $param->{posting})                 or return;

  seek $handle, $pos, 0                                               or return;
  read ($handle, $buf, $reclen) == $reclen                            or return;

  my ($posting, $thread, $views, $votings) = unpack 'L4' => $buf;
  $thread == 0xFFFFFFFF and $thread = $param->{thread};

  $param->{thread} == $thread                                         or return;
  $param->{posting} == $posting                                       or return;

  seek $file, 0, 0                                                    or return;
  my @records = <$file>;
  chomp @records;

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
        } [split ' ' => $_,3]
      } @records
    }
  };

  # looks good
  1;
}

### sub summary ################################################################
#
# read out the cache and return a summary
#
# Params: ~none~
#
# Return: hash reference or false
#
sub summary {
  my $self = shift;

  $self -> read_wrap (\&r_summary)
    ? $self -> {summary}
    : return;
}
sub r_summary {
  my ($self, $handle) = @_;
  my $reclen  = length (pack 'L', 0) << 2;
  my $len = -s $handle;
  my $num = int ($len / $reclen) -1;
  my ($buf, %hash);
  local $/;

  seek $handle, 0, 0                                 or return;
  read ($handle, $buf, $len)                         or return;
  for (0..$num) {
    my ($posting, $thread, $views, $votings)
      = (unpack 'L4' => substr ($buf, $_ * $reclen, $reclen));

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

### sub add_voting #############################################################
#
# add a voting
#
# Params: $param - hash reference
#                  (thread, posting, IP, ID, time)
#
# Return: Status code (Bool)
#
sub add_voting {
  my ($self, $param) = @_;

  $self -> vote_wrap (
    \&r_add_voting,
    $param
  );
}
sub r_add_voting {
  my ($self, $handle, $file, $param) = @_;
  my $reclen  = length (pack 'L', 0) << 2;
  my $pos;
  defined ($pos = find_pos $handle, $param->{posting})          or return;

  my $buf;
  seek $handle, $pos, 0                                         or return;
  read ($handle, $buf, $reclen) == $reclen                      or return;

  my ($posting, $thread, $views, $votings) = unpack 'L4' => $buf;
  $thread == 0xFFFFFFFF and $thread = $param->{thread};

  $param->{thread} == $thread                                   or return;

  {
    local $\="\n";
    seek $file, 0, 2                                            or return;
    print $file
      join (' ' => $param->{time}, $param->{IP}, $param->{ID})  or return;
  }

  {
    local $\;
    seek $handle, $pos, 0                                       or return;
    print $handle
      pack ('L4' => $posting, $thread, $views, $votings+1)      or return;
  }

  1;
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
sub add_posting {
  my $self = shift;
  $self -> add_wrap (
    \&r_add_posting,
    @_
  );
}
sub r_add_posting {
  my ($self, $handle, $param) = @_;
  my $newfile = new Lock ($self->cachefile($param));
  local $\;

  unless (-d $self -> threaddir($param)) {
    mkdir $self->threaddir($param), 0777             or return;
  }
  $newfile -> open (O_WRONLY | O_CREAT | O_TRUNC)    or return;
  $newfile -> close                                  or return;

  my $z;
  if (-s $handle) {
    my $reclen = length (pack 'L' => 0) << 2;
    seek $handle, 0-$reclen, 2                       or return;
    my $buf;
    read ($handle, $buf, $reclen) == $reclen         or return;
    $z = unpack 'L' => $buf;
    if ($z < $param->{posting}) {
      while (++$z < $param->{posting}) {
        seek $handle, 0, 2                           or return;
        print $handle pack(
          'L4' => $z, 0xFFFFFFFF, 0, 0
        )                                            or return;
      }
      $z = undef;
    }
    else {
      my $pos;
      defined (
        $pos = find_pos $handle, $param->{posting}
      )                                              or return;
      seek $handle, $pos, 0                          or return;
    }
  }

  unless (defined $z) {
    seek $handle, 0, 2                               or return;
  }

  print $handle pack(
    'L4' => $param->{posting}, $param->{thread}, 0, 0
  )                                                  or return;

  $newfile -> release;

  1;
}

### sub add_wrap ################################################################
#
# file lock, open, execute, close, unlock wrapper
# for adding an empty entry
#
# Params: $gosub - sub reference (for execution)
#         @param - params (for $gosub)
#
# Return: Status code (Bool)
#
sub add_wrap {
  my ($self, $gosub, @param) = @_;
  my $status;
  my $summary = new Lock ($self -> summaryfile);

  unless ($summary -> lock (LH_EXCL)) {
    $self->set_error ('could not write-lock summary file '.$summary -> filename);
  }
  else {
    unless ($summary -> open($O_BINARY | O_APPEND | O_CREAT | O_RDWR)) {
      $self->set_error
        ('could not open to read/write/append summary file '.$summary->filename);
    }
    else {
      $status = $gosub -> (
        $self,
        $summary,
        @param
      );
      unless ($summary -> close) {
        $status=0;
        $self->set_error('could not close summary file '.$summary -> filename);
      }
    }
    $summary -> unlock;
  }

  # return
  $status;
}

### sub vote_wrap ###############################################################
#
# file lock, open, execute, close, unlock wrapper
# for adding a vote
#
# Params: $gosub - sub reference (for execution)
#         @param - params (for $gosub)
#
# Return: Status code (Bool)
#
sub vote_wrap {
  my ($self, $gosub, $param) = @_;
  my $status;
  my $summary = new Lock ($self -> summaryfile);

  unless ($summary -> lock (LH_EXCL)) {
    $self->set_error ('could not write-lock summary file '.$summary -> filename);
  }
  else {
    unless ($summary -> open (O_RDWR | $O_BINARY)) {
      $self->set_error ('could not open to read/write summary file '.$summary -> filename);
    }
    else {
      unless (-d $self->threaddir($param)) {
        mkdir $self->threaddir($param), 0777                     or return;
      }
      my $cache = new Lock ($self->cachefile($param));

      unless ($cache -> lock (LH_EXCL)) {
        $self->set_error ('could not write-lock cache file '.$cache -> filename);
      }
      else {
        unless ($cache -> open (O_APPEND | O_CREAT | O_RDWR)) {
          $self->set_error ('could not open to read/write/append cache file '.$cache -> filename);
        }
        else {
          $status = $gosub -> (
            $self,
            $summary,
            $cache,
            $param
          );
          unless ($cache -> close) {
            $status=0;
            $self->set_error('could not close cache file '.$cache -> filename);
          }
        }
        $cache -> unlock;
      }
      unless ($summary -> close) {
        $status=0;
        $self->set_error('could not close summary file '.$summary -> filename);
      }
    }
    $summary -> unlock;
  }

  # return
  $status;
}

### sub purge_wrap ##############################################################
#
# file lock, open, execute, close, unlock wrapper
# for garbage collection
#
# Params: $gosub - sub reference (for execution)
#         @param - params (for $gosub)
#
# Return: Status code (Bool)
#
sub purge_wrap {
  my ($self, $gosub, @param) = @_;
  my $status;
  my $summary = new Lock ($self -> summaryfile);

  unless ($summary -> lock (LH_EXSH)) {
    $self->set_error ('could not write-lock summary file '.$summary -> filename);
  }
  else {
    my $temp = new Lock::Handle ($summary -> filename . '.temp');
    unless ($temp -> open (O_CREAT | O_WRONLY | O_TRUNC | $O_BINARY)) {
      $self->set_error ('could not open to write temp summary file '.$temp -> filename);
    }
    else {
      unless ($summary -> open (O_RDONLY | $O_BINARY)) {
        $self->set_error ('could not open to read summary file '.$summary -> filename);
      }
      else {
        $status = $gosub -> (
          $self,
          $summary,
          $temp,
          @param
        );
        unless ($summary -> close) {
          $status = 0;
          $self->set_error('could not close summary file '.$summary -> filename);
        }
      }
      unless ($temp -> close) {
        $status=0;
        $self->set_error('could not close temp summary file '.$temp -> filename);
      }
      unless ($summary -> lock (LH_EXCL)) {
        $status=0;
        $self->set_error ('could not write-lock summary file '.$summary -> filename);
      }
      if ($status) {
        unless (rename $temp -> filename => $summary -> filename) {
          $status=0;
          $self->set_error('could not rename temp summary file '.$temp -> filename);
        }
      }
    }
    $summary -> unlock;
  }

  # return
  $status;
}

### sub pick_wrap ###############################################################
#
# file lock, open, execute, close, unlock wrapper
# for picking a posting
#
# Params: $gosub - sub reference (for execution)
#         @param - params (for $gosub)
#
# Return: Status code (Bool)
#
sub pick_wrap {
  my ($self, $gosub, $filename, @param) = @_;
  my $status;
  my $cache = new Lock ($filename);

  unless ($cache -> lock (LH_SHARED)) {
    $self->set_error ('could not lock cache file '.$cache -> filename);
  }
  else {
    unless ($cache -> open (O_RDONLY)) {
      $self->set_error ('could not open to read cache file '.$cache -> filename);
    }
    else {
      $status = $self -> read_wrap (
        $gosub,
        $cache,
        @param
      );
      unless ($cache -> close) {
        $status=0;
        $self->set_error('could not close cache file '.$cache -> filename);
      }
    }
    $cache -> unlock;
  }

  # return
  $status;
}

### sub read_wrap ###############################################################
#
# file lock, open, execute, close, unlock wrapper
# for reading of summary file
#
# Params: $gosub - sub reference (for execution)
#         @param - params (for $gosub)
#
# Return: Status code (Bool)
#
sub read_wrap {
  my ($self, $gosub, @param) = @_;
  my $status;
  my $summary = new Lock ($self -> summaryfile);

  unless ($summary -> lock (LH_SHARED)) {
    $self->set_error ('could not read-lock summary file '.$summary -> filename);
  }
  else {
    unless ($summary -> open (O_RDONLY | $O_BINARY)) {
      $self->set_error ('could not open to read summary file '.$summary -> filename);
    }
    else {
      $status = $gosub -> (
        $self,
        $summary,
        @param
      );
      unless ($summary -> close) {
        $status=0;
        $self->set_error('could not close summary file '.$summary -> filename);
      }
    }
    $summary -> unlock;
  }

  # return
  $status;
}

### sub mod_wrap ################################################################
#
# file lock, open, execute, close, unlock wrapper
# for modification of summary file
#
# Params: $gosub - sub reference (for execution)
#         @param - params (for $gosub)
#
# Return: Status code (Bool)
#
sub mod_wrap {
  my ($self, $gosub, @param) = @_;
  my $status;
  my $summary = new Lock ($self -> summaryfile);

  unless ($summary -> lock (LH_EXCL)) {
    $self->set_error ('could not write-lock summary file '.$summary -> filename);
  }
  else {
    unless ($summary -> open (O_RDWR | $O_BINARY)) {
      $self->set_error ('could not open to read/write summary file '.$summary -> filename);
    }
    else {
      $status = $gosub -> (
        $self,
        $summary,
        @param
      );
      unless ($summary -> close) {
        $status=0;
        $self->set_error('could not close summary file '.$summary -> filename);
      }
    }
    $summary -> unlock;
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