package Arc::Test;

################################################################################
#                                                                              #
# File:        shared/Arc/Test.pm                                              #
#                                                                              #
# Authors:     Andr� Malo <nd@o3media.de>                                      #
#                                                                              #
# Description: check on obsolete threads                                       #
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
@EXPORT = qw(get_obsolete_threads);

### sub get_obsolete_threads ($) ###############################################
#
# check forum main file on obsolete threads
#
# Params: $param - hash reference
#                  (parsedThreads, adminDefault)
#
# Return: array reference containing the obsolete thread numbers
#         (may be empty)
#
sub get_obsolete_threads ($) {
  my $param = shift;

  my $thread_count = keys %{$param->{parsedThreads}};

  my ($msg_count, $main_size, $tid, %tinfo) = (0, 0);
  for $tid (keys %{$param->{parsedThreads}}) {
    my $num = @{$param->{parsedThreads}->{$tid}};
    $msg_count += $num;

    my ($age, $size) = (0, 0);
    for (@{$param->{parsedThreads}->{$tid}}) {
      $age   = ($age > $_->{time}) ? $age : $_->{time};
      $size +=
        length ($_->{name})
      + length ($_->{cat})
      + length ($_->{subject});
    }
    $size      += $num * 190 + 30;  # we guess a little bit ;-)
    $main_size += $size;

    $tinfo{$tid} = {
      num  => $num,
      age  => $age,
      size => $size
    };
  }
  $main_size += 140;

  my $sev_opt;
  if ($param -> {adminDefault} -> {Severance} -> {severance} eq 'instant') {
    $sev_opt = $param -> {adminDefault} -> {Instant} -> {Severance};
  }
  else {
    $sev_opt = $param -> {adminDefault} -> {Severance};
  };

  my @sorted;
  if ($sev_opt->{severance} eq 'asymmetrical') {
    @sorted = sort {$tinfo{$a}->{age} <=> $tinfo{$b}->{age}} keys %tinfo;
  }
  else {
    @sorted = sort {$a <=> $b} keys %tinfo;
  }

  my $obsolete = 0;

  # max size
  #
  if ($sev_opt -> {afterByte}) {
    while ($main_size > $sev_opt -> {afterByte}) {
      $main_size -= $tinfo{$sorted[$obsolete]}->{size};
      $msg_count -= $tinfo{$sorted[$obsolete]}->{num};
      $thread_count--;
    }
    continue {
      $obsolete++;
    }
  }

  # max messages
  #
  if ($sev_opt -> {afterMessage}) {
    while ($msg_count > $sev_opt -> {afterMessage}) {
      $msg_count -= $tinfo{$sorted[$obsolete]}->{num};
      $thread_count--;
    }
    continue {
      $obsolete++;
    }
  }

  # max threads
  #
  $obsolete += $thread_count - $sev_opt -> {afterThread}
    if ($sev_opt -> {afterThread} and $thread_count > $sev_opt -> {afterThread});

  # return
  [sort {$a <=> $b} splice @sorted => 0, $obsolete];
}

# keep 'require' happy
1;

#
#
### end of Arc::Test ###########################################################