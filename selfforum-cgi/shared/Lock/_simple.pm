package Lock::_simple;

################################################################################
#                                                                              #
# File:        shared/Lock/_simple.pm                                          #
#                                                                              #
# Authors:     Andre Malo       <nd@o3media.de>, 2001-05-25                    #
#                                                                              #
# Description: belongs to Locking and Filehandle class                         #
#              NOT FOR PUBLIC USE                                              #
#                                                                              #
################################################################################

use strict;
use vars qw(
  $VERSION
);

use Fcntl;

################################################################################
#
# Version check
#
$VERSION = do { my @r =(q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

### sub _simple_esna ###########################################################
#
# simple file lock
# excl shared lock announced, no locking possible
#
# Params: $filename - filename
#         $timeout  - timeout
#
# Return: success code (boolean)
#
sub _simple_esna {
  my ($self, $filename, $timeout) = @_;
  my $fh = new Lock::Handle ($filename);

  for (0..$timeout) {
    unless ($self -> exsh_announced) {
      $self -> _simple_lock ($fh) and return 1;
    }
    sleep 1;
  }

  # timeout
  return;
}

### sub _simple_ana ############################################################
#
# simple file lock
# while excl lock announced, no locking possible
#
# Params: $filename - filename
#         $timeout  - timeout
#
# Return: success code (boolean)
#
sub _simple_ana {
  my ($self, $filename, $timeout) = @_;
  my $fh = new Lock::Handle ($filename);

  for (0..$timeout) {
    unless ($self -> excl_announced) {
      $self -> _simple_lock ($fh) and return 1;
    }
    sleep 1;
  }

  # timeout
  return;
}

### sub _simple_aa #############################################################
#
# simple file lock
# while excl lock announced, locking is possible
#
# Params: $filename - filename
#         $timeout  - timeout
#
# Return: success code (boolean)
#
sub _simple_aa {
  my ($self, $filename, $timeout) = @_;
  my $fh = new Lock::Handle ($filename);

  for (0..$timeout) {
    $self -> _simple_lock ($fh) and return 1;
    sleep 1;
  }

  # timeout
  return;
}

### sub es_add_ref #############################################################
#
# increase shared lock reference counter
# (for excl shared lock)
#
# Params: $timeout - timeout
#
# Return: success code (boolean)
#
sub es_add_ref {
  my ($self, $timeout) = @_;

  # lock reference counter file
  # increase reference counter
  # set excl shared lock
  # release ref. counter file
  #
  return unless($self -> _simple_esna ($self->reflock, $timeout));
  $self -> set_ref ($self -> get_ref + 1)                       or return;
  $self -> set_exsh_announce                                    or return;
  $self -> _simple_unlock ($self -> reflock)                    or return;

  # successfully done
  1;
}

### sub es_sub_ref #############################################################
#
# decrease shared lock reference counter
# (of an excl shared locked file)
#
# Params: $timeout - timeout
#
# Return: success code (boolean)
#
sub es_sub_ref {
  my ($self, $timeout) = @_;

  # lock reference counter file
  # increase reference counter
  # release ref. counter file
  #
  return unless($self -> _simple_aa ($self->reflock, $timeout));
  $self -> set_ref ($self -> get_ref - 1)                       or return;
  $self -> remove_exsh_announce;
  $self -> _simple_unlock ($self -> reflock)                    or return;

  # successfully done
  1;
}

### sub add_ref ################################################################
#
# increase shared lock reference counter
#
# Params: $timeout - timeout
#
# Return: success code (boolean)
#
sub add_ref {
  my ($self, $timeout) = @_;

  # lock reference counter file
  # increase reference counter
  # release ref. counter file
  #
  return unless($self -> _simple_ana ($self->reflock, $timeout));
  $self -> set_ref ($self -> get_ref + 1)                       or return;
  $self -> _simple_unlock ($self -> reflock)                    or return;

  # successfully done
  1;
}

### sub sub_ref ################################################################
#
# decrease shared lock reference counter
#
# Params: $timeout - timeout
#
# Return: success code (boolean)
#
sub sub_ref {
  my ($self, $timeout) = @_;

  # lock reference counter file
  # increase reference counter
  # release ref. counter file
  #
  return unless($self -> _simple_aa ($self->reflock, $timeout));
  $self -> set_ref ($self -> get_ref - 1)                       or return;
  $self -> _simple_unlock ($self -> reflock)                    or return;

  # successfully done
  1;
}

### sub get_ref ################################################################
#
# read out the reference counter
# NO LOCKING HERE!
#
# Params: ~none~
#
# Return: counter value
#
sub get_ref {
  my $self = shift;
  my ($fh, $val) = new Lock::Handle ($self -> reffile);

  {
    local $/;
    sysopen ($fh, $fh->filename, O_RDONLY)                      or return 0;
    $val = <$fh>;
    close $fh;
  }

  # return value
  #
  $val;
}

### sub set_ref ################################################################
#
# write reference counter into file
# NO LOCKING HERE!
#
# Params: counter value
#
# Return: success code (boolean)
#
sub set_ref {
  my ($self, $val) = @_;
  my $fh = new Lock::Handle ($self -> reffile);

  if ($val == 0) {
    if (-f $fh->filename) {
      unlink $fh->filename                                      or return;
    }
  }
  else {
    local $\;
    sysopen ($fh, $fh->filename, O_WRONLY | O_TRUNC | O_CREAT)  or return;
    print $fh $val                                              or do {
                                                                  close $fh;
                                                                  unlink $fh->filename;
                                                                  return;
                                                                };

    close $fh                                                   or do {
                                                                  unlink $fh->filename;
                                                                  return;
                                                                };
  }

  # successfully done
  #
  1;
}

### sub set_excl_announce ######################################################
#
# try to announce an exclusive lock
#
# Params: ~none~
#
# Return: status (boolean)
#
sub set_excl_announce {
  my $self = shift;

  if ($self -> excl_announced) {
    return ($self -> announced) ? 1 : return;
  }

  if ($self -> _simple_lock (new Lock::Handle ($self -> lockfile))) {
    $self -> set_static (announced => 1);
    return 1;
  }

  return;
}

### sub remove_excl_announce ###################################################
#
# remove announce of an exclusive lock, if it's set by ourself
#
# Params: ~none~
#
# Return: ~none~
#
sub remove_excl_announce {
  my $self = shift;

  if ($self -> excl_announced and $self -> announced) {
    $self -> _simple_unlock ($self -> lockfile);
  }

  $self -> set_static (announced => 0);

  return;
}

### sub set_exsh_announce ######################################################
#
# try to announce an exclusive shared lock
#
# Params: ~none~
#
# Return: status (boolean)
#
sub set_exsh_announce {
  my $self = shift;

  if ($self -> exsh_announced) {
    return ($self -> es_announced) ? 1 : return;
  }

  if ($self -> _simple_lock (new Lock::Handle ($self -> exshlock))) {
    $self -> set_static (es_announced => 1);
    return 1;
  }

  return;
}

### sub remove_exsh_announce ###################################################
#
# remove an exclusive shared lock, if it's set by ourself
#
# Params: ~none~
#
# Return: ~none~
#
sub remove_exsh_announce {
  my $self = shift;

  if ($self -> exsh_announced and $self -> es_announced) {
    $self -> _simple_unlock ($self -> exshlock);
  }

  $self -> set_static (es_announced => 0);

  return;
}

# keep 'require' happy
1;

#
#
### end of Lock::_simple #######################################################