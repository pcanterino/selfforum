package Arc::Starter;

################################################################################
#                                                                              #
# File:        shared/Arc/Starter.pm                                           #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>                                      #
#                                                                              #
# Description: start severancer and archiver                                   #
#                                                                              #
################################################################################

use strict;
use vars qw(
  @EXPORT
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

################################################################################
#
# Export
#
use base qw(Exporter);
@EXPORT = qw(start_severance);

### win32_start () #############################################################
#
# win32 starter
#
# Params: ~none~
#
# Return: ~none~
#
sub win32_start ($) {
  my $sev = shift;
  my $p;
  my $x = $^X;

  require Win32::Process; Win32::Process -> import ('NORMAL_PRIORITY_CLASS', 'DETACHED_PROCESS');
  require Win32;

  eval q{
    Win32::Process::Create(
      $p,
      $x,
      "perl $sev",
      0,
      NORMAL_PRIORITY_CLASS | DETACHED_PROCESS,
      "."
    ) or warn 'could not execute severancer: '.Win32::FormatMessage(Win32::GetLastError());
  }
}

### posix_start () #############################################################
#
# POSIX starter
#
# Params: ~none~
#
# Return: ~none~
#
sub posix_start ($) {
  my $sev = shift;
  my $x   = $^X;

  require POSIX;

  my $pid = fork;
  unless ($pid) {
    unless (defined $pid) {
      warn "Could not fork severance process: $!";
    }
    else {
      unless (POSIX::setsid()) {
        warn "Could not create new severancer session: $!";
      } else {
        exec $x, $sev;
      }
      warn "could not execute severancer: $!"
    }
  }
}

### start_severance () #########################################################
#
# start the severance script as a new process (group)
#
# Params: $app - /path/to/fo_sev.pl
#
# Return: ~none~
#
sub start_severance ($) {
  my $app = shift;
  my $OS;

  unless ($OS = $^O) {
    require Config;
    $OS = $Config::Config{osname};
  }

  if ($OS =~ /win32/i) {
    win32_start ($app);
  }
  else {
    posix_start ($app);
  }

  return;
}

# keep 'require' happy
1;

#
#
### end of Arc::Starter ########################################################