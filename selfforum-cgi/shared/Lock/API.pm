package Lock::API;

################################################################################
#                                                                              #
# File:        shared/Lock/API.pm                                              #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>                                      #
#                                                                              #
# Description: system independent part of Locking and Filehandle class         #
#              NOT FOR PUBLIC USE                                              #
#                                                                              #
################################################################################

use strict;
use Carp;

use base qw(
  Lock::Handle
  Lock::_simple
);

################################################################################
#
# Version check
#
# last modified:
#    $Date$ (GMT)
# by $Author$
#
sub VERSION {(q$Revision$ =~ /([\d.]+)\s*$/)[0] or '0.0'}

### sub lock ###################################################################
#
# set a lock on the file
#
# Params: $locktype - what kind of locking?
#         $timeout  - (optional) Timeout
#
# Return: success (boolean)
#
sub lock {
  my $self = shift;
  my $locktype = shift;

  return if $self -> masterlocked;

  ###########################################
  # shared lock
  #
  if ($locktype == $self -> LH_SHARED) {
    return 1 if $self -> locked_shared;
    return   if $self -> locked_exclusive;

    my $timeout  = shift || $self -> timeout ('shared');

    # try to increase the reference counter
    #
    if ($self -> add_ref($timeout)) {
      $self -> set_static (locked_shared => 1);
      return 1;
    }
  }


  ###########################################
  # exclusive lock
  #
  elsif ($locktype == $self -> LH_EXCL) {
    return 1 if $self -> locked_exclusive;

    my $timeout  = shift || $self -> timeout ('exclusive');

    #####################
    # transform exclusive shared lock into exclusive lock
    #
    if ($self -> locked_exsh) {
      my $reflock = new Lock::Handle ($self -> reflock);

      for (0..$timeout) {
        if ($self -> set_excl_announce and $self -> _simple_lock ($reflock)) {
          if ($self -> get_ref == 1) {
            $self -> set_ref(0);
            $self -> remove_exsh_announce;
            $self -> set_static (locked_exsh      => 0);
            $self -> set_static (locked_exclusive => 1);
            return 1;
          }

          last unless ($self -> _simple_unlock ($reflock->filename));
        }

        sleep 1;
      }
      $self -> remove_excl_announce;
    }

    #####################
    # set exclusive lock
    #
    else {
      my $reflock = new Lock::Handle ($self -> reflock);

      for (0..$timeout) {
        if ($self -> set_excl_announce and $self -> _simple_lock ($reflock)) {
          if ($self -> get_ref == 0) {
            $self -> set_static (locked_exclusive => 1);
            return 1;
          }

          last unless ($self -> _simple_unlock ($reflock->filename));
        }

        sleep 1;
      }
      $self -> remove_excl_announce;
    }
  }


  ###########################################
  # exclusive shared lock
  #
  elsif ($locktype == $self -> LH_EXSH) {
    return 1 if $self -> locked_exsh;
    return   if ($self -> locked_shared or $self -> locked_exclusive);

    my $timeout  = shift || $self -> timeout ('shared');

    # try to increase the reference counter
    #
    if ($self -> es_add_ref($timeout)) {
      $self -> set_static (locked_exsh => 1);
      return 1;
    }
  }


  ###########################################
  # master lock
  #
  elsif ($locktype == $self -> LH_MASTER) {
    $self -> lock ($self->LH_EXCL, $self -> timeout('master'))   and
    $self -> _simple_lock (new Lock::Handle ($self->masterlock)) and
    return 1;

    # oops..?
    # VERY violent way to set master lock
    #
    $self -> release;

    $self -> lock ($self->LH_EXCL, $self -> timeout('master'))   and
    $self -> _simple_lock (new Lock::Handle ($self->masterlock)) and
    return 1;
  }

  ###########################################
  # unknown locking type
  #
  else {
    croak "unknown locking type '$locktype'";
  }

  # timeout
  #
  $self -> unlock_violent;
  return;
}

### sub unlock #################################################################
#
# remove shared or exclusive lock
#
# Params: $timeout - (optional) Timeout
#
# Return: success (boolean)
#
sub unlock {
  my $self = shift;
  my $timeout = shift || $self -> timeout ('shared');

  return if $self -> masterlocked;

  ###########################################
  # shared lock
  #
  if ($self -> locked_shared) {
    # try to decrease the reference counter
    #
    if ($self -> sub_ref($timeout)) {
      $self -> set_static (locked_shared => 0);
      return 1;
    }
  }


  ###########################################
  # exclusive lock
  #
  elsif ($self -> locked_exclusive) {
    my $reflock = new Lock::Handle ($self -> reflock);

    for (0..$timeout) {
      if ($self -> _simple_unlock ($reflock->filename)) {
        $self -> remove_excl_announce;
        $self -> set_static (locked_exclusive => 0);
        return 1;
      }

      sleep 1;
    }
  }


  ###########################################
  # exclusive shared lock
  #
  elsif ($self -> locked_exsh) {
    # try to decrease the reference counter
    #
    if ($self -> es_sub_ref($timeout)) {
      $self -> remove_exsh_announce;
      $self -> set_static (locked_exsh => 0);
      return 1;
    }
  }


  ###########################################
  # not locked
  #
  else {
    return 1;
  }

  # unlocking failed
  #
  $self -> unlock_violent;
  return;
}

### sub unlock_violent #########################################################
#
# remove any lock violently  (excludes master lock)
#
# Params: ~none~
#
# Return: -none- (the success is undefined)
#
sub unlock_violent {
  my $self = shift;

  unless ($self -> masterlocked) {

    # find out last modification time
    # and do nothing unless 'violent-timout' is over
    #
    my $time = $self -> _reftime;

    if ($time) {
      return if ((time - $time) < $self -> timeout('violent'));
    }

    $self -> set_ref (0);                        # reference counter = 0
    $self -> _simple_unlock ($self -> reflock);  # release reference counter file
    $self -> _simple_unlock ($self -> exshlock); # remove excl shared lock
    $self -> _simple_unlock ($self -> lockfile); # release file
  }

  return;
}

### sub release ################################################################
#
# release a file
#
# Params: ~none~
#
# Return: ~none~
#
sub release {
  my $self = shift;

  $self -> set_ref (0);                           # reference counter = 0
  $self -> _simple_unlock ($self -> reflock);     # release reference counter
  $self -> _simple_unlock ($self -> lockfile);    # remove any write lock announce
  $self -> _simple_unlock ($self -> exshlock);    # remove any excl shared lock
  $self -> _simple_unlock ($self -> masterlock);  # remove master lock

  return;
}

# keep 'require' happy
1;

#
#
### end of Lock::API ###########################################################