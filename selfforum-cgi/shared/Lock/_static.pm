package Lock::_static;

################################################################################
#                                                                              #
# File:        shared/Lock/_static.pm                                          #
#                                                                              #
# Authors:     Andre Malo       <nd@o3media.de>, 2001-05-25                    #
#                                                                              #
# Description: belongs to Locking and Filehandle class                         #
#              NO PUBLIC USE                                                   #
#              save the lock object static information                         #
#              (because the lock object is a blessed file handle)              #
#                                                                              #
################################################################################

use strict;
use vars qw(
  $VERSION
);

use Carp;

################################################################################
#
# Version check
#
$VERSION = do { my @r =(q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

################################################################################
#
# Variables
#
my (%static, %access);

# define standard timeouts
# (seconds)
#
my %timeout = (
  shared     => 10,       # for shared and exclusive shared locks
  exclusive  => 10,       # for exclusive locks
  violent    => 600,      # for violent unlocks (10 minutes should justify a process abort)
  master     => 20        # for master locks
);

### timeout ####################################################################
#
# set and read out the timeout
#
# Params: $type - timeout type (defined in %timeout, see above)
#                 in this case, the specified timeout will be returned
#         OR
#         %hash - (type => time) pairs
#                  the specified timouts will be set
#
# Return: specified timeout or nothing
#
sub timeout {
  my ($self, @ary) = @_;

  return if (@ary == 0);

  if (@ary == 1) {
    my $type = shift @ary;
    my $hash = $self -> get_static('timeout') || {};

    return defined $hash->{$type}
    ? $hash -> {$type}
    : $timeout {$type};
  }

  my %hash = @ary;
  $self->set_static(timeout => {%{$self -> get_static('timeout') || {}},%hash});

  return;
}

### set_static #################################################################
#
# set an object property
#
# Params: $key   - property and method name
#         $value - property
#
# Return: $value or nothing
#
sub set_static {
  my ($self, $key, $value) = @_;

  $static{$self}={} unless exists($static{$self});
  $static{$self}->{$key} = $value;

  defined wantarray and return $value;
  return;
}

### get_static #################################################################
#
# read out an object property
#
# Params: $key - property name
#
# Return: value or false
#
sub get_static {
  my ($self, $key) = @_;

  return unless exists($static{$self});
  $static{$self}->{$key};
}

################################################################################
#
# define the lock file names
#
sub reffile    {shift -> filename . '.lock.ref'}
sub lockfile   {shift -> filename . '.lock'}
sub reflock    {shift -> filename . '.lock.ref.lock'}
sub exshlock   {shift -> filename . '.exshlock'}
sub masterlock {shift -> filename . '.masterlock'}

################################################################################
#
# autoload the general access methods
#
BEGIN {
  %access = map {$_=>1} qw(
    filename
    locked_shared
    locked_exclusive
    locked_exsh
    es_announced
    announced
  );
}
AUTOLOAD {
  my $self = shift;
  (my $attr = $Lock::_static::AUTOLOAD) =~ s/.*:://;
  return if ($attr eq 'DESTROY');

  if ($access{$attr}) {
    return $self -> get_static($attr);
  }
  else {
    eval {
      local $SIG{__DIE__};
      my $sup = "SUPER::$attr";
      return $self -> $sup(@_);
    };
    croak $@;
  }
}

################################################################################
#
# destrcutor - try to unlock, if neccessary and possible
#
DESTROY {
  my $self = shift;

  $self -> unlock if ($self =~ /^Lock=/);
  delete $static{$self};
}

################################################################################
#
# terminator, catch sigTERM and (try to) destroy all objects
#
sub destroy_all {
  $SIG{TERM} = \&destroy_all;

  $_ -> unlock for (grep ((ref $_ and /^Lock=/) => keys %static));

  exit (0);
}
BEGIN {
  $SIG{TERM} = \&destroy_all;
}

# keep 'require' happy
1;

#
#
### end of Lock::_static #######################################################