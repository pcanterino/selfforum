# Template.pm

# ====================================================
# Autor: n.d.p. / 2001-01-06
# lm   : n.d.p. / 2001-01-25
# ====================================================
# Funktion:
#      Ausfuellen von Templates
# ====================================================

use strict;

package Template;

use CGI::Carp qw(croak);
use XML::DOM;

# ====================================================
# Methoden
# ====================================================

################################
# sub new
#
# Konstruktor
################################

sub new {
  my $instance=shift;
  my $class=(ref($instance) or $instance);

  my $self = {};
  $self = bless $self,$class;

  $self -> file (+shift);

  # Rueckgabe
  $self;
}

################################
# sub file
#
# Datei zuweisen und parsen
################################

sub file {
  my $self = shift;
  my $old = $self -> {file};
  my $new = shift;

  $self -> {file} = $new if (defined $new);
  $self -> parse_file;

  $old;
}

################################
# sub insert
#
# Bezeichner in Metazeichen
# eingeschlossen zurueckgeben
################################

sub insert {
  my $self=shift;
  croak "no template file specified" unless (defined $self -> {file});

  my $name=shift;

  # Rueckgabe
  $self -> {metaon} . $name . $self -> {metaoff};
}

################################
# sub list
#
# komplette Liste einsetzen
################################

sub list {
  my $self=shift;
  my $name=shift;

  croak "no template file specified" unless (defined $self->{file});

  my $list = join '', map { ${ $self -> scrap ($name, $_) } } @{ +shift };

  # Rueckgabe
  \$list;
}

################################
# sub scrap
#
# Schnipsel ausfuellen
################################

sub scrap {
  my $self=shift;
  my $name=shift;

  croak "no template file specified" unless (defined $self->{file});

  my %params;

  # Parameter holen
  # Als Values werden nur die Referenzen gespeichert
  %params = map { my $ref = $_; map { ($_ => ( (ref ($ref -> {$_} ) )?$ref -> {$_}: \($ref -> {$_} ) ) ) } keys %$ref } splice @_;

  # und einsetzen
  my $scrap=$self->{parsed}->{$name};
  my $qmon=quotemeta $self->{metaon};
  my $qmoff=quotemeta $self->{metaoff};

  # und zwar solange, bis nichts mehr da ist
  while ($scrap =~ s<$qmon\s*([_a-zA-Z]\S*)\s*$qmoff>[
    my $x='';
    if ( exists ( $params{$1} ) ) { $x = ${$params{$1}} }
    elsif (exists ( $self -> {parsed} -> {$1} ) ) { $x = $self -> {parsed} -> {$1}}
    $x;]geo ){};

  $self -> parse_if (\$scrap,\%params);

  # Rueckgabe
  \$scrap;
}

# ====================================================
# Private Funktionen/Methoden
# ====================================================

################################
# sub parse_file
#
# Template einlesen & parsen
################################

sub parse_file {
  my $self = shift;

  if (-f $self -> {file}) {
    my $filename = $self -> {file};
    my $xml = new XML::DOM::Parser -> parsefile ($filename);
    my $template = $xml -> getElementsByTagName ('Template', 0) -> item (0);

    # Metas bestimmen
    $self -> {metaon}  = $template -> getAttribute ('metaon');
    $self -> {metaoff} = $template -> getAttribute ('metaoff');

    croak "missing meta defintion(s) in template file '$filename'." unless ($self -> {metaon} and $self -> {metaoff});

    $self -> {parsed} = {};
    foreach ($template -> getElementsByTagName ('Scrap', 0)) {
      my $name = $_ -> getAttribute ('id');

      croak "Element 'Scrap' requires attribute 'id' in template file '$filename'." unless (length ($name));
      croak "double defined id '$name' in template file '$filename'." if (exists ($self -> {parsed} -> {$name}));
      croak "use '/^[_a-zA-Z]\\S*\$/' for 'Scrap'-ids in template file '$filename' (wrong: '$name')." unless ($name =~ /^[_a-zA-Z]\S*$/);

      $self -> {parsed} -> {$name} = $_ -> getFirstChild -> getData;
      $self -> {parsed} -> {$name} =~ s/^\s+|\s+$//g;}

    return 1; # alles klar
  }

  0;
}

################################
# sub parse_if
#
# %IF - Anweisungen parsen
################################

sub parse_if {
  my $self = shift;
  my ($scrap,$params) = @_;

  my $qmon  = quotemeta $self -> {metaon};
  my $qmoff = quotemeta $self -> {metaoff};

  # der folgende Regex ist ein bisschen fies ...
  # ... aber er funktioniert :-)
  #
  # pfff - rekursive Strukturen iterativ parsen ist nicht wirklich witzig
  while ($$scrap=~s[ ($qmon\s*%(?:IF|ELSE)\s+.+?\s*$qmoff.*?) # Wenn IF oder ELSE von
                     (?=$qmon\s*%IF\s+.+?\s*$qmoff)           # IF gefolgt werden, soll
                                                              # dieses Stueck uebersprungen
                                                              # werden und erstmal mit der
                                                              # naechsten Ebene weitergemacht
                                                              # werden.

                    |(                                        # hier beginnt $2
                      $qmon\s*%IF\s+(.+?)\s*$qmoff            # IF
                      (.*?)                                   # $4
                      (?:
                        $qmon\s*%ENDIF\s*$qmoff               # gefolgt von ENDIF
                       |                                      # oder
                        $qmon\s*%ELSE\s*$qmoff                # von ELSE... ($4 ELSE $5) $5 $6
                        (.*?)
                        $qmon\s*%ENDIF\s*$qmoff               # und ENDIF
                      )
                     )
                   ]
                   [my $ret;
                    if ($2) {
                      my ($t4,$t5,$t6) = ($4,$5,$6);
                      my $flag=0;
                      foreach (split /\s+/,$3) {
                        if (exists($params->{$_}) and length(${$params->{$_}})) {$ret = $t4; $flag=1;last;}}
                      $ret = $t5 unless ($flag);}
                    else {$ret=$1;}
                    $ret;
                   ]gosex) {};

  return;
}

# ====================================================
# Modulinitialisierung
# ====================================================

# making require happy
1;

# ====================================================
# end of Template
# ====================================================