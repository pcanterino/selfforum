package Lock::Exclusive;

################################################################################
#                                                                              #
# File:        shared/Lock/Exclusive.pm                                        #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>                                      #
#                                                                              #
# Description: Locking and Filehandle class                                    #
#              using O_EXCL and lock files                                     #
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

### sub _simple_lock ###########################################################
#
# simple file lock
# (create lock file)
#
# Params: $filename - file to lock
#         $timeout  - timeout
#
# Return: success (boolean)
#
sub _simple_lock {
  my ($self, $fh) = @_;

  sysopen ($fh, $fh->filename, O_CREAT | O_EXCL | O_WRONLY)
    and close $fh
    and return 1;

  return;
}

### sub _simple_unlock #########################################################
#
# simple file unlock
# (unlink lock file)
#
# Params: $filename - lockfile name
#                     ^^^^^^^^
#
# Return: success (boolean)
#
sub _simple_unlock {
  my ($self, $filename) = @_;

  return 1 if (!-f $filename or unlink $filename);

  # not able to unlink lock file, hmmm...
  #
  return;
}

### sub _reftime ###############################################################
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

### sub masterlocked ###########################################################
#
# check on master lock status of the file
#
# Params: ~none~
#
# Return: status (boolean)
#
sub masterlocked {-f shift -> masterlock}

### sub excl_announced #########################################################
#
# check on exclusive lock announced status of the file
#
# Params: ~none~
#
# Return: status (boolean)
#
sub excl_announced {-f shift -> lockfile}

### sub exsh_announced #########################################################
#
# check on exclusive shared lock status of the file
#
# Params: ~none~
#
# Return: status (boolean)
#
sub exsh_announced {-f shift -> exshlock}

# keep 'require' happy
1;

#
#
### end of Lock::Exclusive #####################################################