# Lock.pm

# ====================================================
# Autor: n.d.p. / 2001-01-04
# lm   : n.d.p. / 2000-01-05
# ====================================================
# Funktion:
#      Sperren einer Datei
# ====================================================

use strict;

package Lock;

use vars qw(@EXPORT_OK %EXPORT_TAGS $Timeout $violentTimeout $masterTimeout $iAmMaster);

# ====================================================
# Funktionsexport
# ====================================================

use base qw(Exporter);

@EXPORT_OK   = qw(lock_file unlock_file write_lock_file write_unlock_file
                  violent_unlock_file set_master_lock release_file);

%EXPORT_TAGS = (READ  => [qw(lock_file unlock_file violent_unlock_file)],
                WRITE => [qw(write_lock_file write_unlock_file violent_unlock_file)],
                ALL   => [qw(lock_file unlock_file write_lock_file write_unlock_file
                             violent_unlock_file set_master_lock release_file)]);

# ====================================================
# Windows section (no symlinks)
# ====================================================

################################
# sub w_lock_file
#
# Schreibsperre setzen
################################

sub w_lock_file ($;$) {
  my $filename=shift;
  my ($timeout)=(shift (@_) or $Timeout);
  my $i;

  if (-f &masterlockfile($filename)) {

    for ($i=0 ; $i<=$timeout ; $i++) {
      # Referenzzaehler um eins erhoehen
      &set_ref($filename,1,$timeout) and return 1;
      sleep (1);}}

  else {
    # Mastersperre
    return undef;}

  0; # Mist
}

################################
# sub w_unlock_file
#
# Schreibsperre aufheben
################################

sub w_unlock_file ($;$) {
  my $filename=shift;
  my ($timeout)=(shift (@_) or $Timeout);

  if (-f &masterlockfile($filename)) {
    # Referenzzaehler um eins erniedrigen
    &set_ref($filename,-1,$timeout) and return 1;}

  0; # Mist
}

################################
# sub w_write_lock_file
#
# Lese- und Schreibsperre
# setzen
################################

sub w_write_lock_file ($;$) {
  my $filename=shift;
  my ($timeout)=(shift (@_) or $Timeout);

  if (-f &masterlockfile($filename) or $iAmMaster) {
    # bevorstehenden Schreibzugriff anmelden
    &simple_lock ($filename,$timeout) or return 0;

    my $i;
    for ($i=0 ; $i<=$timeout ; $i++) {
      # Referenzdatei sperren
      &simple_lock (&reffile($filename),$timeout) or (return &simple_unlock($filename,$timeout) and 0);

      # Referenzzaehler = 0 ? => okay
      return 1 if (&get_ref ($filename) == 0);

      # Referenzdatei wieder freigeben
      &simple_unlock (&reffile($filename),$timeout) or (return &simple_unlock($filename,$timeout) and 0);
      sleep(1);}

    &simple_unlock ($filename);}

  else {
    # Mastersperre gesetzt
    return undef;}

  0; # Mist
}

################################
# sub w_write_unlock_file
#
# Lese- und Schreibsperre
# aufheben
################################

sub w_write_unlock_file ($;$) {
  my $filename=shift;
  my ($timeout)=(shift (@_) or $Timeout);

  if (-f &masterlockfile($filename) or $iAmMaster) {
    &simple_unlock (&reffile($filename),$timeout) or return 0; # Referenzdatei freigeben
    &simple_unlock ($filename,$timeout) or return 0;}          # Lesesperre aufheben

  1; # jawoll!
}

################################
# sub w_violent_unlock_file
#
# Sperre brutal aufheben
################################

sub w_violent_unlock_file ($) {
  my $filename=shift;

  if (-f &masterlockfile($filename)) {

    # Zeit der letzten Modifikation feststellen
    # und abbrechen, wenn meine Zeit noch nicht gekommen ist
    my $reffile;
    if (-f ($reffile = $filename) or -f ($reffile = &lockfile($filename))) {
      my $time = (stat $reffile)[9];
      return if ((time - $time) < $violentTimeout);}

    write_lock_file ($filename,1);       # letzter Versuch, exklusiven Zugriff zu bekommen
    unlink (&reffile($filename));        # Referenzzaehler auf null
    simple_unlock (&reffile($filename)); # Referenzdatei freigeben
    simple_unlock ($filename);}          # Datei freigeben (Lesesperre aufheben)
}

################################
# sub w_set_master_lock
#
# Mastersperre setzen
################################

sub w_set_master_lock ($;$) {
  my $filename=shift;
  my $timeout=(shift @_ or $masterTimeout);

  # exklusiven Zugriff erlangen...oder abbrechen
  return 0 unless (&write_lock_file ($filename,$timeout));

  # Mastersperre setzen und Erfolg melden
  unlink &masterlockfile($filename) and return 1;

  0; # Mist
}

################################
# sub w_release_file
#
# Alle Sperren inkl. Master-
# sperre aufheben
################################

sub w_release_file ($) {
  my $filename=shift;

  unlink (&reffile($filename));                              # Referenzzaehler auf null
  return 0 if (-f &reffile($filename));                      # wirklich?
  return 0 unless (simple_unlock (&reffile($filename)));     # Referenzzaehler freigeben
  return 0 unless (&simple_unlock ($filename));              # Datei selbst freigeben (Lesesperre)
  return 0 unless (&simple_unlock (&masterfile($filename))); # Mastersperre aufheben

  1; # jup
}

# ====================================================
# *n*x section (symlinks possible)
# ====================================================

################################
# sub x_lock_file
#
# Schreibsperre setzen
################################

sub x_lock_file ($;$) {
  my $filename=shift;
  my ($timeout)=(shift (@_) or $Timeout);
  my $i;

  unless (-l &masterlockfile($filename)) {

    for ($i=0 ; $i<=$timeout ; $i++) {
      # Referenzzaehler um eins erhoehen
      &set_ref($filename,1,$timeout) and return 1;
      sleep (1);}}

  else {
    # Mastersperre
    return undef;}

  0; # Mist
}

################################
# sub x_unlock_file
#
# Schreibsperre aufheben
################################

sub x_unlock_file ($;$) {
  my $filename=shift;
  my ($timeout)=(shift (@_) or $Timeout);

  unless (-l &masterlockfile($filename)) {
    # Referenzzaehler um eins erniedrigen
    &set_ref($filename,-1,$timeout) and return 1;}

  0; # Mist
}

################################
# sub x_write_lock_file
#
# Lese- und Schreibsperre
# setzen
################################

sub x_write_lock_file ($;$) {
  my $filename=shift;
  my ($timeout)=(shift (@_) or $Timeout);

  unless (-l &masterlockfile($filename) and not $iAmMaster) {
    # bevorstehenden Schreibzugriff anmelden
    &simple_lock ($filename,$timeout) or return 0;

    my $i;
    for ($i=0 ; $i<=$timeout ; $i++) {
      # Referenzdatei sperren
      &simple_lock (&reffile($filename),$timeout) or (return &simple_unlock($filename,$timeout) and 0);

      # Referenzzaehler = 0 ? => okay
      return 1 if (&get_ref ($filename) == 0);

      # Referenzdatei wieder freigeben
      &simple_unlock (&reffile($filename),$timeout) or (return &simple_unlock($filename,$timeout) and 0);
      sleep(1);}

    &simple_unlock ($filename);}

  else {
    # Mastersperre gesetzt
    return undef;}

  0; # Mist
}

################################
# sub x_write_unlock_file
#
# Lese- und Schreibsperre
# aufheben
################################

sub x_write_unlock_file ($;$) {
  my $filename=shift;
  my ($timeout)=(shift (@_) or $Timeout);

  unless (-l &masterlockfile($filename) and not $iAmMaster) {
    &simple_unlock (&reffile($filename),$timeout) or return 0; # Referenzdatei freigeben
    &simple_unlock ($filename,$timeout) or return 0;}          # Lesesperre aufheben

  1; # jawoll!
}

################################
# sub x_violent_unlock_file
#
# Sperre brutal aufheben
################################

sub x_violent_unlock_file ($) {
  my $filename=shift;

  unless (-l &masterlockfile($filename)) {

    # Zeit der letzten Modifikation feststellen
    # und abbrechen, wenn meine Zeit noch nicht gekommen ist
    my ($reffile,$time);

    if (-f ($reffile = $filename)) {
      $time = (stat $reffile)[9];}

    elsif (-l ($reffile = &lockfile($filename))) {
      $time = (lstat $reffile)[9];}

    if ($reffile) {
      return if ((time - $time) < $violentTimeout);}

    write_lock_file ($filename,1);       # letzter Versuch, exklusiven Zugriff zu bekommen
    unlink (&reffile($filename));        # Referenzzaehler auf null
    simple_unlock (&reffile($filename)); # Referenzdatei freigeben
    simple_unlock ($filename);}          # Datei freigeben (Lesesperre aufheben)
}

################################
# sub x_set_master_lock
#
# Mastersperre setzen
################################

sub x_set_master_lock ($;$) {
  my $filename=shift;
  my $timeout=(shift @_ or $masterTimeout);

  # exklusiven Zugriff erlangen...oder abbrechen
  return 0 unless (&write_lock_file ($filename,$timeout));

  # Mastersperre setzen und Erfolg melden
  symlink $filename, &masterlockfile($filename) and return 1;

  0; # Mist
}

################################
# sub x_release_file
#
# Alle Sperren inkl. Master-
# sperre aufheben
################################

sub x_release_file ($) {
  my $filename=shift;

  unlink (&reffile($filename));                              # Referenzzaehler auf null
  return 0 if (-f &reffile($filename));                      # wirklich?
  return 0 unless (simple_unlock (&reffile($filename)));     # Referenzzaehler freigeben
  return 0 unless (&simple_unlock ($filename));              # Datei selbst freigeben (Lesesperre)
  return 0 unless (&simple_unlock (&masterfile($filename))); # Mastersperre aufheben

  1; # jup
}

# ====================================================
# private subs
# ====================================================

################################
# Dateinamen
################################

sub reffile ($) {
  "$_[0].lock.ref";
}
sub lockfile ($) {
  "$_[0].lock";
}
sub masterlockfile ($) {
  &lockfile(&masterfile($_[0]));
}
sub masterfile ($) {
  "$_[0].master";
}

################################
# einfaches Sperren/Entsperren
# Windows
#
# (Lockdatei loeschen)
################################

sub w_simple_lock ($;$) {
  my $filename=shift;
  my ($timeout)=(shift (@_) or $Timeout);
  my $lockfile=&lockfile($filename);

  my $i;
  for ($i=$timeout; $i>=0; $i--) {
    unlink("$lockfile") and return 1;
    sleep(1);}

  0; # Mist
}

sub w_simple_unlock ($) {
  my $filename=shift;
  my $lockfile=&lockfile($filename);
  my $flag=1;
  local *LF;

  open(LF, ">$lockfile") or $flag=0;
  close(LF) or $flag=0;

  # Rueckgabe
  $flag;
}

################################
# einfaches Sperren/Entsperren
# *n*x
#
# (symlink setzen)
################################

sub x_simple_lock ($;$) {
  my $filename=shift;
  my ($timeout)=(shift (@_) or $Timeout);
  my $lockfile=&lockfile($filename);

  my $i;
  for ($i=$timeout; $i>=0; $i--) {
    symlink $filename,$lockfile and return 1;
    sleep(1);}

  0; # Mist
}

sub x_simple_unlock ($) {
  my $filename=shift;

  unlink (&lockfile($filename)) and return 1;

  0; # hmmm...
}

################################
# sub w_set_ref
# Windows
#
# Referenzzaehler um $_[1]
# erhoehen
# (kann auch negativ sein...)
################################

sub w_set_ref ($$$) {
  my ($filename,$z)=@_;
  my $timeout=(shift @_ or $Timeout);
  my $old;
  my $reffile=&reffile($filename);
  local *REF;


  # runterzaehlen - ja, neue Leseversuche - nein
  if ($z > 0) {
    return 0 unless(-e &lockfile($filename));}

  # Referenzdatei locken
  return 0 unless(&simple_lock ($reffile,$timeout));

  # Referenzdatei auslesen
  unless (open REF,"<$reffile") {
    $old=0;}
  else {
    $old=<REF>;
    chomp $old;
    close REF or return 0;}

  # Neuen Referenzwert schreiben
  $old+=$z;
  $old=0 if ($old < 0);
  if ($old == 0)
  {
    unlink $reffile or return 0;
  }
  else
  {
    open REF,">$reffile" or return 0;
    print REF $old or return 0;
    close REF or return 0;
  }

  # wieder entsperren
  return 0 unless(&simple_unlock($reffile));

  1;
}

################################
# sub x_set_ref
# *n*x
#
# Referenzzaehler um $_[1]
# erhoehen
# (kann auch negativ sein...)
################################

sub x_set_ref ($$$) {
  my ($filename,$z)=@_;
  my $timeout=(shift @_ or $Timeout);
  my $old;
  my $reffile=&reffile($filename);
  local *REF;


  # runterzaehlen - ja, neue Leseversuche - nein
  if ($z > 0) {
    return 0 if(-l &lockfile($filename));}

  # Referenzdatei locken
  return 0 unless(&simple_lock ($reffile,$timeout));

  # Referenzdatei auslesen
  unless (open REF,"<$reffile") {
    $old=0;}
  else {
    $old=<REF>;
    chomp $old;
    close REF or return 0;}

  # Neuen Referenzwert schreiben
  $old += $z;
  $old = 0 if ($old < 0);
  if ($old == 0)
  {
    unlink $reffile or return 0;
  }
  else
  {
    open REF,">$reffile" or return 0;
    print REF $old or return 0;
    close REF or return 0;
  }

  # wieder entsperren
  return 0 unless(&simple_unlock($reffile));

  1;
}

################################
# sub get_ref
#
# Referenzzaehler auslesen
#
# Das Locking muss an
# anderer Stelle ausgefuehrt
# werden!
################################

sub get_ref ($$) {
  my $filename=shift;
  my $reffile=&reffile($filename);
  my $old;
  local *REF;

  unless (open REF,"<$reffile") {
    $old=0;}
  else {
    $old=<REF>;
    chomp $old;
    close REF or return 0;}

  # Rueckgabe
  $old;
}

# ====================================================
# Modulinitialisierung
# ====================================================

BEGIN {
  # Globale Variablen (Zeiten in Sekunden)
  $Timeout        =  10; # normaler Timeout
  $violentTimeout = 600; # zum gewaltsamen Entsperren (10 Minuten)
  $masterTimeout  =  20; # fuer die Mastersperre

  $iAmMaster = 0;        # erstmal bin ich kein Master :-)

  # wirkliche Funktionen ihren Bezeichnern zuweisen
  # (perldoc -f symlink)

  if ( eval {local $SIG{__DIE__}; symlink('',''); 1 } ) {
    *lock_file           = \&x_lock_file;
    *unlock_file         = \&x_unlock_file;
    *write_lock_file     = \&x_write_lock_file;
    *write_unlock_file   = \&x_write_unlock_file;
    *violent_unlock_file = \&x_violent_unlock_file;
    *set_master_lock     = \&x_set_master_lock;
    *release_file        = \&x_release_file;

    *simple_lock         = \&x_simple_lock;
    *simple_unlock       = \&x_simple_unlock;
    *set_ref             = \&x_set_ref;}

  else {
    *lock_file           = \&w_lock_file;
    *unlock_file         = \&w_unlock_file;
    *write_lock_file     = \&w_write_lock_file;
    *write_unlock_file   = \&w_write_unlock_file;
    *violent_unlock_file = \&w_violent_unlock_file;
    *set_master_lock     = \&w_set_master_lock;
    *release_file        = \&w_release_file;

    *simple_lock         = \&w_simple_lock;
    *simple_unlock       = \&w_simple_unlock;
    *set_ref             = \&w_set_ref;}
}

# making require happy
1;

# ====================================================
# end of Lock
# ====================================================