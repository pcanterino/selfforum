package Lock;

################################################################################
#                                                                              #
# File:        shared/Lock.pm                                                  #
#                                                                              #
# Authors:     Andre Malo       <nd@o3media.de>, 2001-04-01                    #
#                                                                              #
# Description: file locking                                                    #
#                                                                              #
################################################################################

use strict;
use vars qw(
  @EXPORT_OK
  %EXPORT_TAGS
  %LOCKED
  $Timeout
  $violentTimeout
  $masterTimeout
  $iAmMaster
  $VERSION
);

use Carp;
use Fcntl;

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

@EXPORT_OK   = qw(
  lock_file
  unlock_file
  write_lock_file
  write_unlock_file
  violent_unlock_file
  set_master_lock
  release_file
  file_removed
);

%EXPORT_TAGS = (
  READ  => [qw(
    lock_file
    unlock_file
    violent_unlock_file
  )],
  WRITE => [qw(
    write_lock_file
    write_unlock_file
    violent_unlock_file
  )],
  ALL   => \@EXPORT_OK
);

### ~file () ###################################################################
#
# create lock file names
#
sub reffile ($) {
  return $_[0].'.lock.ref';
}
sub lockfile ($) {
  return $_[0].'.lock';
}
sub masterfile ($) {
  return $_[0].'.master';
}
sub masterlockfile ($) {
  return lockfile(masterfile $_[0]);
}

################################################################################
#
# Windows section (no symlinks)
#

### w_lock_file () #############################################################
#
# set read lock (shared lock)
# (for no-symlink-systems)
#
# Params: $filename - file to lock
#         $timeout  - Lock Timeout (sec.)
#
# Return: Status Code (Bool)
#
sub w_lock_file ($;$) {
  my $filename = shift;
  my $timeout  = +shift || $Timeout;

  unless ($LOCKED{$filename}) {
    if (-f masterlockfile($filename)) {
      for (1..$timeout) {

        # try to increment the reference counter
        #
        if (set_ref($filename,1,$timeout)) {
          $LOCKED{$filename}=1;
          return 1;
        }
        sleep (1);
      }
    }
    else {
      # master lock is set or file has not been released yet
      return;
    }
  }

  # time out
  # maybe the system is occupied
  0;
}

### w_unlock_file () ###########################################################
#
# remove read lock (shared lock)
# (for no-symlink-systems)
#
# Params: $filename - locked file
#         $timeout  - timeout (sec.)
#
# Return: Status Code (Bool)
#
sub w_unlock_file ($;$) {
  my $filename = shift;
  my $timeout  = shift || $Timeout;

  if ($LOCKED{$filename}) {
    if ($LOCKED{$filename} == 3) {
      return unless write_unlock_file($filename, $timeout);
      $LOCKED{$filename} = 1;
    }
    if ($LOCKED{$filename} == 1) {
      if (-f masterlockfile($filename)) {

        # try do decrement the reference counter
        #
        if (set_ref($filename, -1, $timeout)) {
          delete $LOCKED{$filename};
          return 1;
        }
      }
    }
  }

  # time out
  return;
}

### w_write_lock_file () #######################################################
#
# set write lock (exclusive lock)
# (for no-symlink-systems)
#
# Params: $filename - file to lock
#         $timeout  - timeout (sec.)
#
# Return: Status Code (Bool)
#
sub w_write_lock_file ($;$) {
  my $filename=shift;
  my $timeout= shift || $Timeout;
  my $rest = ($LOCKED{$filename} and $LOCKED{$filename} == 1) ? 1 : 0;

  if (-f masterlockfile($filename) or $iAmMaster) {

    # announce the write lock
    # and wait $timeout seconds for
    # references == 0 (no shared locks set)
    #
    simple_lock ($filename,$timeout) or return 0;
    for (1..$timeout) {
      # lock reference counter
      # or fail
      #
      unless (simple_lock (reffile($filename),$timeout)) {
        simple_unlock($filename,$timeout);
        return 0;
      }

      # ready if we have no shared locks
      #
      if (get_ref ($filename) == $rest) {
        $LOCKED{$filename} = 2 | ($rest ? 1 : 0);
        return 1;
      };

      # release reference counter
      # shared locks get the chance to be removed
      #
      unless (simple_unlock (reffile($filename),$timeout)) {
        simple_unlock($filename,$timeout);
        return 0;
      }
      sleep(1);
    }

    # write lock failed
    # remove the announcement
    #
    simple_unlock ($filename);
  }

  else {
    # master lock is set or file has not been released yet
    return;
  }

  # time out
  0;
}

### w_write_unlock_file () #####################################################
#
# remove write lock (exclusive lock)
# (for no-symlink-systems)
#
# Params: $filename - locked file
#         $timeout  - timeout (sec.)
#
# Return: Status Code (Bool)
#
sub w_write_unlock_file ($;$) {
  my $filename = shift;
  my $timeout  = shift || $Timeout;

  if (-f masterlockfile($filename) or $iAmMaster) {

    # remove reference counter lock
    #
    simple_unlock (reffile($filename),$timeout) or return;

    # remove the write lock announce
    #
    simple_unlock ($filename,$timeout) or return;
  }

  # done
  delete $LOCKED{$filename};
  1;
}

### w_violent_unlock_file () ###################################################
#
# remove any lock violent  (excl. master lock)
# (for no-symlink-systems)
#
# Params: $filename - locked file
#
# Return: -none- (the success is not defined)
#
sub w_violent_unlock_file ($) {
  my $filename = shift;

  if (-f masterlockfile($filename)) {

    # find out last modification time
    # and do nothing unless 'violent-timout' is over
    #
    my $reffile;
    if (-f ($reffile = $filename) or -f ($reffile = lockfile($filename))) {
      my $time = (stat $reffile)[9];
      (time - $time) >= $violentTimeout   or return;
    }

    write_lock_file ($filename,1);       # last try, to set an exclusive lock on $filename
    unlink (reffile($filename));         # reference counter = 0
    simple_unlock (reffile($filename));  # release reference counter file
    simple_unlock ($filename);}          # release file
    delete $LOCKED{$filename};

  return;
}

### w_set_master_lock () #######################################################
#
# set master lock
# (for no-symlink-systems)
#
# Params: $filename - file to lock
#         $timeout  - timeout (sec.)
#
# Return: Status Code (Bool)
#
sub w_set_master_lock ($;$) {
  my $filename = shift;
  my $timeout  = shift || $masterTimeout;

  # set exclusive lock or fail
  #
  return unless (write_lock_file ($filename,$timeout));

  # set master lock
  #
  unlink masterlockfile($filename)    and return 1;

  # no chance (occupied?, master lock set yet?)
  return;
}

### w_release_file () ##########################################################
#
# remove any locks (incl. master lock)
# (for no-symlink-systems)
#
# Params: $filename - file to lock
#         $timeout  - timeout (sec.)
#
# Return: Status Code (Bool)
#
sub w_release_file ($) {
  my $filename=shift;

  unlink (reffile($filename));                              # reference counter = 0
  return if (-f reffile($filename));                        # really?
  return unless (simple_unlock (reffile($filename)));       # release reference counter
  return unless (simple_unlock ($filename));                # remove any write lock announce
  return unless (simple_unlock (masterfile($filename)));    # remove master lock
  delete $LOCKED{$filename};

  # done
  1;
}

sub w_file_removed ($) {
  my $filename = shift;

  unlink reffile($filename);
  unlink lockfile($filename);
  unlink lockfile(reffile($filename));
  unlink masterlockfile($filename);
}

################################################################################
#
# *n*x section (symlinks possible)
#

### x_lock_file () #############################################################
#
# set read lock (shared lock)
# (symlinks possible)
#
# Params: $filename - file to lock
#         $timeout  - Lock Timeout (sec.)
#
# Return: Status Code (Bool)
#
sub x_lock_file ($;$) {
  my $filename = shift;
  my $timeout  = shift || $Timeout;

  unless ($LOCKED{$filename}) {
    unless (-l masterlockfile($filename)) {
      for (1..$timeout) {

        # try to increment the reference counter
        #
        if (set_ref($filename,1,$timeout)) {
          $LOCKED{$filename} = 1;
          return 1;
        }
        sleep (1);
      }
    }

    else {
      # master lock is set or file has not been realeased yet
      return;
    }
  }

  # time out
  0;
}

### x_unlock_file () ###########################################################
#
# remove read lock (shared lock)
# (symlinks possible)
#
# Params: $filename - locked file
#         $timeout  - timeout (sec.)
#
# Return: Status Code (Bool)
#
sub x_unlock_file ($;$) {
  my $filename=shift;
  my ($timeout)=(shift (@_) or $Timeout);

  if ($LOCKED{$filename}) {
    if ($LOCKED{$filename} == 3) {
      return unless write_unlock_file($filename, $timeout);
      $LOCKED{$filename} = 1;
    }
    if ($LOCKED{$filename} == 1) {
      unless (-l masterlockfile($filename)) {
        # try to decrement the reference counter
        #
        set_ref($filename,-1,$timeout) and do {
          delete $LOCKED{$filename};
          return 1;
        }
      }

      # time out
      return;
    }
  }
}

### x_write_lock_file () #######################################################
#
# set write lock (exclusive lock)
# (symlinks possible)
#
# Params: $filename - file to lock
#         $timeout  - timeout (sec.)
#
# Return: Status Code (Bool)
#
sub x_write_lock_file ($;$) {
  my $filename = shift;
  my $timeout  = shift || $Timeout;
  my $rest = ($LOCKED{$filename} and $LOCKED{$filename} == 1) ? 1 : 0;

  unless (-l masterlockfile($filename) and not $iAmMaster) {
    # announce the write lock
    # and wait $timeout seconds for
    # references == 0 (no shared locks set)
    #
    simple_lock ($filename,$timeout) or return 0;
    for (1..$timeout) {

      # lock reference counter
      # or fail
      #
      unless (simple_lock (&reffile($filename),$timeout)) {
        simple_unlock($filename,$timeout);
        return 0;
      }

      # ready if we have no shared locks
      #
      if (get_ref ($filename) == $rest) {
        $LOCKED{$filename} = 2 | ($rest ? 1 : 0);
        return 1;
      };

      # release reference counter
      # shared locks get the chance to be removed
      #
      unless (simple_unlock (&reffile($filename),$timeout)) {
        simple_unlock($filename,$timeout);
        return 0;
      }
      sleep(1);
    }

    # write lock failed
    # remove the announcement
    #
    simple_unlock ($filename);
  }

  else {
    # master lock is set
    # or file has not been released yet
    #
    return;
  }

  # time out
  # maybe the system is occupied
  #
  0;
}

### x_write_unlock_file () #####################################################
#
# remove write lock (exclusive lock)
# (symlinks possible)
#
# Params: $filename - locked file
#         $timeout  - timeout (sec.)
#
# Return: Status Code (Bool)
#
sub x_write_unlock_file ($;$) {
  my $filename = shift;
  my $timeout  = shift || $Timeout;

  unless (-l &masterlockfile($filename) and not $iAmMaster) {
    # remove reference counter lock
    #
    simple_unlock (reffile($filename),$timeout) or return;

    # remove the write lock announce
    #
    simple_unlock ($filename,$timeout) or return;
  }

  # done
  delete $LOCKED{$filename};
  1;
}

### x_violent_unlock_file () ###################################################
#
# remove any lock violent  (excl. master lock)
# (symlinks possible)
#
# Params: $filename - locked file
#
# Return: -none- (the success is not defined)
#
sub x_violent_unlock_file ($) {
  my $filename=shift;

  unless (-l &masterlockfile($filename)) {

    # find out last modification time
    # and do nothing unless 'violent-timout' is over
    #
    my ($reffile,$time);

    if (-f ($reffile = $filename)) {
      $time = (stat $reffile)[9];}

    elsif (-l ($reffile = lockfile($filename))) {
      $time = (lstat $reffile)[9];}

    if ($reffile) {
      return if ((time - $time) < $violentTimeout);}

    write_lock_file ($filename,1);       # last try, to set an exclusive lock on $filename
    unlink (reffile($filename));         # reference counter = 0
    simple_unlock (reffile($filename));  # release reference counter file
    simple_unlock ($filename);}          # release file
    delete $LOCKED{$filename};
}

### x_set_master_lock () #######################################################
#
# set master lock
# (symlinks possible)
#
# Params: $filename - file to lock
#         $timeout  - timeout (sec.)
#
# Return: Status Code (Bool)
#
sub x_set_master_lock ($;$) {
  my $filename = shift;
  my $timeout  = shift || $masterTimeout;

  # set exclusive lock or fail
  #
  return unless (write_lock_file ($filename,$timeout));

  # set master lock
  #
  symlink $filename, masterlockfile($filename) and return 1;

  # no chance (occupied?, master lock set yet?)
  return;
}

### x_release_file () ##########################################################
#
# remove any locks (incl. master lock)
# (symlinks possible)
#
# Params: $filename - file to lock
#         $timeout  - timeout (sec.)
#
# Return: Status Code (Bool)
#
sub x_release_file ($) {
  my $filename=shift;

  unlink (reffile($filename));                            # reference counter = 0
  return if (-f reffile($filename));                      # really?
  return unless (simple_unlock (reffile($filename)));     # release reference counter
  return unless (simple_unlock ($filename));              # remove any write lock announce
  return unless (simple_unlock (masterfile($filename)));  # remove master lock
  delete $LOCKED{$filename};

  # done
  1;
}

sub x_file_removed ($) {
  release_file (shift);
}

### w_simple_lock () ###########################################################
### w_simple_unlock () #########################################################
#
# simple file lock/unlock
# (for no-symlink-systems: kill/create lockfile)
#
# Params: $filename  - file to lock
#         [ $timeout - Lock time out (sec.) ]
#
# Return: Status Code (Bool)
#
sub w_simple_lock ($;$) {
  my $filename = shift;
  my $timeout  = shift || $Timeout;
  my $lockfile = lockfile $filename;

  for (0..$timeout) {
    unlink $lockfile and return 1;
    sleep(1);
  }

  # timeout
  # occupied?
  return;
}

sub w_simple_unlock ($) {
  my $filename = shift;
  my $lockfile = lockfile $filename;
  local *LF;

  if (sysopen(LF, $lockfile, O_WRONLY|O_CREAT|O_TRUNC)) {
    return 1 if close (LF);
  }

  # not able to create lockfile, hmmm...
  #
  return;
}

### x_simple_lock () ###########################################################
### x_simple_unlock () #########################################################
#
# simple file lock/unlock
# (symlinks possible: create/unlink symlink)
#
# Params: $filename  - file to lock
#         [ $timeout - Lock time out (sec.) ]
#
# Return: Status Code (Bool)
#
sub x_simple_lock ($;$) {
  my $filename = shift;
  my $timeout  = shift || $Timeout;
  my $lockfile = lockfile $filename;

  for (0..$timeout) {
    symlink $filename,$lockfile and return 1;
    sleep(1);
  }

  # time out
  return;
}

sub x_simple_unlock ($) {
  my $filename=shift;

  unlink (lockfile $filename) and return 1;

  # not able to unlink symlink, hmmm...
  #
  return;
}

### w_set_ref () ###############################################################
#
# add $_[1] to reference counter
# (may be negative...)
# (for no-symlink-systems)
#
# Params: $filename - file, reference counter belongs to
#         $z        - value, added to reference counter
#         $timeout  - lock time out
#
# Return: Status Code (Bool)
#
sub w_set_ref ($$$) {
  my $filename = shift;
  my $z        = shift;
  my $timeout  = shift || $Timeout;
  my $reffile  = reffile $filename;
  local *REF;

  # if write lock announced, only count down allowed
  #
  ($z < 0 or -f lockfile ($filename))                     or return;

  # lock reference counter file
  #
  simple_lock ($reffile,$timeout)                         or return;

  # load reference counter
  #
  my $old = get_ref ($filename);

  # compute and write new ref. counter
  #
  $old += $z;
  $old = 0 if ($old < 0);

  # kill reference counter file
  # if ref. counter == 0
  #
  if ($old == 0) {
    unlink $reffile                                       or return;
  }
  else {
    local $\;
    sysopen (REF, $reffile, O_WRONLY | O_TRUNC | O_CREAT) or return;
    print REF $old                                        or do {
                                                            close REF;
                                                            return
                                                          };
    close REF                                             or return;
  }

  # release ref. counter file
  #
  simple_unlock($reffile)                                 or return;

  # done
  1;
}

### x_set_ref () ###############################################################
#
# add $_[1] to reference counter
# (may be negative...)
# (symlinks possible)
#
# Params: $filename - file, reference counter belongs to
#         $z        - value, added to reference counter
#         $timeout  - lock time out
#
# Return: Status Code (Bool)
#
sub x_set_ref ($$$) {
  my $filename = shift;
  my $z        = shift;
  my $timeout  = shift || $Timeout;
  my $reffile  = reffile $filename;
  local *REF;

  # if write lock announced, only count down allowed
  #
  if ($z > 0) {
    return if(-l lockfile($filename));
  }

  # lock reference counter file
  #
  return unless(simple_lock ($reffile,$timeout));

  # load reference counter
  #
  my $old = get_ref ($filename);

  # compute and write new ref. counter
  #
  $old += $z;
  $old = 0 if ($old < 0);

  if ($old == 0) {
    unlink $reffile                                       or return;
  }
  else {
    local $\;
    sysopen (REF, $reffile, O_WRONLY | O_TRUNC | O_CREAT) or return;
    print REF $old                                        or do {
                                                            close REF;
                                                            return
                                                          };
    close REF                                             or return;
  }

  # release ref. counter file
  #
  simple_unlock($reffile)                                 or return;

  # done
  1;
}

### get_ref () #################################################################
#
# read out the reference counter
# (system independant)
# no locking here!
#
# Params: $filename - file, the ref. counter belongs to
#
# Return: reference counter
#
sub get_ref ($) {
  my $filename = shift;
  my $reffile  = reffile $filename;
  my $old;
  local *REF;
  local $/;

  sysopen (REF, $reffile, O_RDONLY)    or return 0;
    $old = <REF>;
  close REF;

  # return value
  $old;
}

################################################################################
#
# initializing the module
#
BEGIN {
  # global variables (time in seconds)
  #
  $Timeout        =  10; # normal timeout
  $violentTimeout = 600; # violent timeout (10 minutes)
  $masterTimeout  =  20; # master timeout

  $iAmMaster = 0;        # default: I am nobody

  %LOCKED = ();

  # assign the aliases to the needed functions
  # (perldoc -f symlink)

  if ( eval {local $SIG{__DIE__}; symlink('',''); 1 } ) {
    *lock_file           = \&x_lock_file;
    *unlock_file         = \&x_unlock_file;
    *write_lock_file     = \&x_write_lock_file;
    *write_unlock_file   = \&x_write_unlock_file;
    *violent_unlock_file = \&x_violent_unlock_file;
    *set_master_lock     = \&x_set_master_lock;
    *release_file        = \&x_release_file;
    *file_removed        = \&x_file_removed;

    *simple_lock         = \&x_simple_lock;
    *simple_unlock       = \&x_simple_unlock;
    *set_ref             = \&x_set_ref;
  }

  else {
    *lock_file           = \&w_lock_file;
    *unlock_file         = \&w_unlock_file;
    *write_lock_file     = \&w_write_lock_file;
    *write_unlock_file   = \&w_write_unlock_file;
    *violent_unlock_file = \&w_violent_unlock_file;
    *set_master_lock     = \&w_set_master_lock;
    *release_file        = \&w_release_file;
    *file_removed        = \&w_file_removed;

    *simple_lock         = \&w_simple_lock;
    *simple_unlock       = \&w_simple_unlock;
    *set_ref             = \&w_set_ref;
  }
}

# keep 'require' happy
1;

#
#
### end of Lock ################################################################