package Lock::Handle;

################################################################################
#                                                                              #
# File:        shared/Lock/Handle.pm                                           #
#                                                                              #
# Authors:     Andre Malo       <nd@o3media.de>, 2001-05-30                    #
#                                                                              #
# Description: belongs to Locking and Filehandle class                         #
#              NOT FOR PUBLIC USE                                              #
#                                                                              #
################################################################################

use strict;
use vars qw(
  $VERSION
);

use base   qw(Lock::_static);

use Symbol qw(gensym);

################################################################################
#
# Version check
#
$VERSION = do { my @r =(q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

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