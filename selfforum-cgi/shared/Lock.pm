package Lock;

################################################################################
#                                                                              #
# File:        shared/Lock.pm                                                  #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>                                      #
#                                                                              #
# Description: Locking and Filehandle class                                    #
#                                                                              #
################################################################################

use strict;
use vars qw($module);

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

################################################################################
#
# load the specific module
#
BEGIN {
  local $SIG{__DIE__};

  $module = 'Lock::'.(
    eval {symlink('',''); 1}
    ? 'Symlink'
    : ( eval {O_EXCL}
      ? 'Exclusive'
      : 'Unlink'
    )
  );
}
use base (
  $module,
  'Lock::API'
);

################################################################################
#
# export constants
#
use constant LH_SHARED => 0;
use constant LH_EXCL   => 1;
use constant LH_EXSH   => 2;
use constant LH_MASTER => 3;

use base 'Exporter';
@Lock::EXPORT = qw(LH_SHARED LH_EXCL LH_EXSH LH_MASTER);

# keep require happy
1;

#
#
### end of Lock ################################################################