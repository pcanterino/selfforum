package Lock::Unlink;

################################################################################
#                                                                              #
# File:        shared/Lock/Unlink.pm                                           #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>                                      #
#                                                                              #
# Description: Locking and Filehandle class                                    #
#              using the atomic behavior of unlinkig files                     #
#                                                                              #
################################################################################

use strict;
use Fcntl;

################################################################################
#
# Version check
#
# last modified:
#    $Date$ (GMT)
# by $Author$
#
sub VERSION {(q$Revision$ =~ /([\d.]+)\s*$/)[0] or '0.0'}

### _simple_lock () ############################################################
#
# simple file lock
# (unlink lock file)
#
# Params: $filename - file to lock
#         $timeout  - timeout
#
# Return: success (boolean)
#
sub _simple_lock {
  my ($self, $fh) = @_;

  unlink $fh -> filename and return 1;

  return;
}

### _simple_unlock () ##########################################################
#
# simple file unlock
# (create lock file)
#
# Params: $filename - lockfile name
#                     ^^^^^^^^
#
# Return: success (boolean)
#
sub _simple_unlock {
  my ($self, $filename) = @_;
  local *LF;

  sysopen (LF, $filename, O_WRONLY | O_CREAT | O_TRUNC)
    and close LF
    and return 1;

  # not able to create lock file, hmmm...
  #
  return;
}

### _reftime () ################################################################
#
# determine reference time for violent unlock
#
# Params: ~none~
#
# Return: time or zero, if no reference file found
#
sub _reftime {
  my $self = shift;
  my ($time, $reffile) = 0;

  if (-f ($reffile = $self -> filename)) {
    $time = (stat $reffile)[9];}

  elsif (-f ($reffile = $self -> lockfile)) {
    $time = (stat $reffile)[9];}

  $time;
}

### masterlocked () ############################################################
#
# check on master lock status of the file
#
# Params: ~none~
#
# Return: status (boolean)
#
sub masterlocked {not -f shift -> masterlock}

### excl_announced () ##########################################################
#
# check on exclusive lock announced status of the file
#
# Params: ~none~
#
# Return: status (boolean)
#
sub excl_announced {not -f shift -> lockfile}

### exsh_announced () ##########################################################
#
# check on exclusive shared lock status of the file
#
# Params: ~none~
#
# Return: status (boolean)
#
sub exsh_announced {not -f shift -> exshlock}

### purge () ###################################################################
#
# cover our traces after a file was removed
#
# Params: ~none~
#
# Return: ~none~
#
sub purge {
  my $self = shift;

  $self -> set_ref (0);          # reference counter = 0
  unlink ($self -> reflock);     # remove reference counter lock
  unlink ($self -> lockfile);    # remove any write lock announce
  unlink ($self -> exshlock);    # remove any excl shared lock
  unlink ($self -> masterlock);  # remove master lock

  return;
}

# keep 'require' happy
1;

#
#
### end of Lock::Unlink ########################################################