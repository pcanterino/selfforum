package Lock::Handle;

################################################################################
#                                                                              #
# File:        shared/Lock/Handle.pm                                           #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>                                      #
#                                                                              #
# Description: belongs to Locking and Filehandle class                         #
#              NOT FOR PUBLIC USE                                              #
#                                                                              #
################################################################################

use strict;
use Symbol qw(gensym);

use base   qw(Lock::_static);

################################################################################
#
# Version check
#
# last modified:
#    $Date$ (GMT)
# by $Author$
#
sub VERSION {(q$Revision$ =~ /([\d.]+)\s*$/)[0] or '0.0'}

### sub new ####################################################################
#
# constructor
#
# Params: $file - filename
#
# Return: Lock object
#
sub new {
  my ($instance, $file) = @_;
  my $class = ref($instance) || $instance;
  my $self  = bless $class -> _create_handle => $class;

  $self -> set_static (filename => $file);

  $self;
}

### open () ####################################################################
#
# open a file
#
# Params: $mode - open mode
#
# Return: success code (boolean)
#
sub open {
  my ($self, $mode) = @_;

  return unless defined ($mode);

  sysopen ($self, $self->filename, $mode);
}

### close () ###################################################################
#
# close a file
#
# Params: ~none~
#
# Return: success code (boolean)
#
sub close {
  my $self = shift;

  CORE::close $self;
}

### sub _create_handle #########################################################
#
# create a globref
#
# Params: ~none~
#
# Return: globref
#
sub _create_handle {gensym}

# keep 'require' happy
1;

#
#
### end of Lock::Handle ########################################################