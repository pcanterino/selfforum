package Lock;

################################################################################
#                                                                              #
# File:        shared/Locked.pm                                                #
#                                                                              #
# Authors:     Andre Malo       <nd@o3media.de>, 2001-05-25                    #
#                                                                              #
# Description: Locking and Filehandle class                                    #
#                                                                              #
################################################################################

use strict;
use vars qw(
  $VERSION
);

use diagnostics;
use vars qw($module);

use Fcntl;

################################################################################
#
# Version check
#
$VERSION = do { my @r =(q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

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

###############
# !!!!!!!!!!!!!!!!!
# remove the following later
###############
package Locked;
use constant LH_SHARED => 0;
use constant LH_EXCL   => 1;
use constant LH_EXSH   => 2;
use constant LH_MASTER => 3;

use base 'Exporter';
@Locked::EXPORT = qw(LH_SHARED LH_EXCL LH_EXSH LH_MASTER);

# keep require happy
1;

#
#
### end of Lock ################################################################