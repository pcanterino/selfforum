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
use Carp;

use vars qw(
  @EXPORT_OK
  %EXPORT_TAGS
  $Timeout
  $violentTimeout
  $masterTimeout
  $iAmMaster
);

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
  ALL   => [qw(
    lock_file
    unlock_file
    write_lock_file
    write_unlock_file
    violent_unlock_file
    set_master_lock
    release_file
  )]
);

################################################################################
#
# Windows section (no symlinks)
#

### sub w_lock_file ($;$) ######################################################
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

  if (-f &masterlockfile($filename)) {
    for (0..$timeout) {

      # try to increment the reference counter
      #
      &set_ref($filename,1,$timeout) and return 1;
      sleep (1);
    }
   }

  else {
    # master lock is set
    # or file has not been realeased yet
    #
    return;
  }

  # time out
  # maybe the system is occupied
  0;
}

### sub w_unlock_file ($;$) ####################################################
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

  if (-f &masterlockfile($filename)) {

    # try do decrement the reference counter
    #
    &set_ref($filename,-1,$timeout) and return 1;
  }

  # time out
  # maybe the system is occupied
  # or file has not been released yet
  #
  return;
}

### sub w_write_lock_file ($;$) ################################################
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

  if (-f &masterlockfile($filename) or $iAmMaster) {

    # announce the write lock
    # and wait $timeout seconds for
    # references == 0 (no shared locks set)
    #
    &simple_lock ($filename,$timeout) or return;
    for (0..$timeout) {
      # lock reference counter
      # or fail
      #
      unless (&simple_lock (&reffile($filename),$timeout)) {
        &simple_unlock($filename,$timeout);
        return;
      }

      # ready if we have no shared locks
      #
      return 1 if (&get_ref ($filename) == 0);

      # release reference counter
      # shared locks get the chance to be removed
      #
      unless (&simple_unlock (&reffile($filename),$timeout)) {
        &simple_unlock($filename,$timeout);
        return;
      }
      sleep(1);
    }

    # write lock failed
    # remove the announcement
    #
    &simple_unlock ($filename);}

  else {
    # master lock is set
    # or file has not been released yet
    #
    return;}

  # time out
  # maybe the system is occupied
  #
  0;
}

### sub w_write_unlock_file ($;$) ##############################################
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

  if (-f &masterlockfile($filename) or $iAmMaster) {

    # remove reference counter lock
    #
    &simple_unlock (&reffile($filename),$timeout) or return;

    # remove the write lock announce
    #
    &simple_unlock ($filename,$timeout) or return;}

  # done
  1;
}

### sub w_violent_unlock_file ($) ##############################################
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

  if (-f &masterlockfile($filename)) {

    # find out last modification time
    # and do nothing unless 'violent-timout' is over
    #
    my $reffile;
    if (-f ($reffile = $filename) or -f ($reffile = &lockfile($filename))) {
      my $time = (stat $reffile)[9];
      return if ((time - $time) < $violentTimeout);}

    write_lock_file ($filename,1);       # last try, to set an exclusive lock on $filename
    unlink (&reffile($filename));        # reference counter = 0
    simple_unlock (&reffile($filename)); # release reference counter file
    simple_unlock ($filename);}          # release file

  return;
}

### sub w_set_master_lock ($;$) ################################################
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
  return unless (&write_lock_file ($filename,$timeout));

  # set master lock
  #
  unlink &masterlockfile($filename) and return 1;

  # no chance (occupied?, master lock set yet?)
  return;
}

### sub w_release_file ($) #####################################################
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

  unlink (&reffile($filename));                              # reference counter = 0
  return if (-f &reffile($filename));                      # really?
  return unless (simple_unlock (&reffile($filename)));     # release reference counter
  return unless (&simple_unlock ($filename));              # remove any write lock announce
  return unless (&simple_unlock (&masterfile($filename))); # remove master lock

  # done
  1;
}

################################################################################
#
# *n*x section (symlinks possible)
#

### sub x_lock_file ($;$) ######################################################
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

  unless (-l &masterlockfile($filename)) {
    for (0..$timeout) {

      # try to increment the reference counter
      #
      &set_ref($filename,1,$timeout) and return 1;
      sleep (1);
    }
  }

  else {
    # master lock is set
    # or file has not been realeased yet
    #
    return;
  }

  # time out
  # maybe the system is occupied
  0;
}

### sub x_unlock_file ($;$) ####################################################
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

  unless (-l &masterlockfile($filename)) {
    # try do decrement the reference counter
    #
    &set_ref($filename,-1,$timeout) and return 1;}

  # time out
  # maybe the system is occupied
  # or file has not been released yet
  #
  return;
}

### sub x_write_lock_file ($;$) ################################################
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

  unless (-l &masterlockfile($filename) and not $iAmMaster) {
    # announce the write lock
    # and wait $timeout seconds for
    # references == 0 (no shared locks set)
    #
    &simple_lock ($filename,$timeout) or return;
    for (0..$timeout) {

      # lock reference counter
      # or fail
      #
      unless (&simple_lock (&reffile($filename),$timeout)) {
        &simple_unlock($filename,$timeout);
        return;
      }

      # ready if we have no shared locks
      #
      return 1 if (&get_ref ($filename) == 0);

      # release reference counter
      # shared locks get the chance to be removed
      #
      unless (&simple_unlock (&reffile($filename),$timeout)) {
        &simple_unlock($filename,$timeout);
        return;
      }
      sleep(1);
    }

    # write lock failed
    # remove the announcement
    #
    &simple_unlock ($filename);}

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

### sub x_write_unlock_file ($;$) ##############################################
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
    &simple_unlock (&reffile($filename),$timeout) or return;

    # remove the write lock announce
    #
    &simple_unlock ($filename,$timeout) or return;
  }

  # done
  1;
}

### sub x_violent_unlock_file ($) ##############################################
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

    elsif (-l ($reffile = &lockfile($filename))) {
      $time = (lstat $reffile)[9];}

    if ($reffile) {
      return if ((time - $time) < $violentTimeout);}

    write_lock_file ($filename,1);       # last try, to set an exclusive lock on $filename
    unlink (&reffile($filename));        # reference counter = 0
    simple_unlock (&reffile($filename)); # release reference counter file
    simple_unlock ($filename);}          # release file
}

### sub x_set_master_lock ($;$) ################################################
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
  return unless (&write_lock_file ($filename,$timeout));

  # set master lock
  #
  symlink $filename, &masterlockfile($filename) and return 1;

  # no chance (occupied?, master lock set yet?)
  return;
}

### sub x_release_file ($) #####################################################
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

  unlink (&reffile($filename));                            # reference counter = 0
  return if (-f &reffile($filename));                      # really?
  return unless (simple_unlock (&reffile($filename)));     # release reference counter
  return unless (&simple_unlock ($filename));              # remove any write lock announce
  return unless (&simple_unlock (&masterfile($filename))); # remove master lock

  # done
  1;
}

################################################################################
#
# private subs
#

### sub ~file ($) ##############################################################
#
# create lock file names
#
sub reffile ($) {
  "$_[0].lock.ref";
}
sub lockfile ($) {
  "$_[0].lock";
}
sub masterlockfile ($) {
  &lockfile(&masterfile($_[0]));
}
sub masterfile ($) {
  "$_[0].master";
}

### sub w_simple_lock ($;$) ####################################################
### sub w_simple_unlock ($) ####################################################
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

  if (open(LF, "> $lockfile")) {
    return 1 if close (LF);
  }

  # not able to create lockfile, hmmm...
  #
  return;
}

### sub w_simple_lock ($;$) ####################################################
### sub w_simple_unlock ($) ####################################################
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
  # locking failed (occupied?)
  #
  return;
}

sub x_simple_unlock ($) {
  my $filename=shift;

  unlink (&lockfile($filename)) and return 1;

  # not able to unlink symlink, hmmm...
  #
  return;
}

### sub w_set_ref ($$$) ########################################################
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
  my $old;
  my $reffile = reffile $filename;
  local *REF;

  # if write lock announced, only count down allowed
  #
  if ($z > 0) {
    return unless(-f lockfile($filename));
  }

  # lock reference counter file
  #
  return unless(&simple_lock ($reffile,$timeout));

  # load reference counter
  #
  unless (open REF,"<$reffile") {
    $old=0;
  }
  else {
    $old=<REF>;
    chomp $old;
    close REF or return;
  }

  # compute and write new ref. counter
  #
  $old += $z;
  $old = 0 if ($old < 0);

  # kill reference counter file
  # if ref. counter == 0
  #
  if ($old == 0) {
    unlink $reffile or return;
  }
  else {
    open REF,">$reffile" or return;
    print REF $old or return;
    close REF or return;
  }

  # release ref. counter file
  #
  return unless(&simple_unlock($reffile));

  # done
  1;
}

### sub x_set_ref ($$$) ########################################################
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
  my $old;
  my $reffile = reffile $filename;
  local *REF;

  # if write lock announced, only count down allowed
  #
  if ($z > 0) {
    return if(-l &lockfile($filename));
  }

  # lock reference counter file
  #
  return unless(&simple_lock ($reffile,$timeout));

  # load reference counter
  #
  unless (open REF,"<$reffile") {
    $old=0;
  }
  else {
    $old=<REF>;
    chomp $old;
    close REF or return;
  }

  # compute and write new ref. counter
  #
  $old += $z;
  $old = 0 if ($old < 0);
  if ($old == 0) {
    unlink $reffile or return;
  }
  else {
    open REF,">$reffile" or return;
    print REF $old or return;
    close REF or return;
  }

  # release ref. counter file
  #
  return unless(&simple_unlock($reffile));

  # done
  1;
}

### sub get_ref ($) ############################################################
#
# read out the reference counter
# (system independant)
# no locking here!
#
# Params: $filename - file, the ref. counter belongs to
#
# Return: reference counter
#
sub get_ref ($$) {
  my $filename = shift;
  my $reffile  = reffile $filename;
  my $old;
  local *REF;

  unless (open REF,"< $reffile") {
    $old = 0;
  }
  else {
    $old=<REF>;
    chomp $old;
    close REF;
  }

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

    *simple_lock         = \&w_simple_lock;
    *simple_unlock       = \&w_simple_unlock;
    *set_ref             = \&w_set_ref;
  }
}

# keeping require happy
1;

#
#
### end of Lock ################################################################
