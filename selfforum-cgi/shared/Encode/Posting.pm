package Encode::Posting;

################################################################################
#                                                                              #
# File:        shared/Encode/Posting.pm                                        #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>, 2001-04-10                          #
#                                                                              #
# Description: prepare a Posting text for saving and visual (HTML) output      #
#                                                                              #
################################################################################

use strict;

use Encode::Plain; $Encode::Plain::utf8 = 1;
use CheckRFC;

################################################################################
#
# Export
#
use base qw(Exporter);
@Encode::Posting::EXPORT = qw(
  encoded_body
  answer_field
  message_field
);

### sub rel_uri ($$) ###########################################################
#
# generate an absolute URI from a absolute|relative one
# (not for public use)
#
# Params: $uri  - URI
#         $base - base URI
#
# Return: abs URI as string
#
sub rel_uri ($$) {
  my ($uri, $base) = @_;

  "http://$ENV{HTTP_HOST}".
    ($uri =~ m|^/|
      ? $uri
      : "$base$uri");
}

### sub encoded_body ($;$) #####################################################
#
# prepare posting text for saving
#
# Params: $posting - scalar reference of the raw text
#         $params  - hash reference
#                    (quoteChars messages)
#
# Return: scalar reference of the encoded text
#
sub encoded_body ($;$) {
  my $posting = ${+shift};
  my $params = shift;

  $posting =~ s/\015\012|\015|\012/\n/g; # normalize newlines
  $posting =~ s/[^\S\n]+$//gm;           # kill whitespaces at the end of all lines
  $posting =~ s/\s+$//;                  # kill whitespaces (newlines) at the end of the string (text)

  # check the special syntaxes:

  my $base = $params -> {base_uri};
  # collect all [link:...] strings
  #
  my @rawlinks;
  push @rawlinks => [$1 => $2] while ($posting =~ /\[([Ll][Ii][Nn][Kk]):\s*([^\]\s]+)\s*\]/g);
  my @links = grep {
       is_URL ( $_ -> [1] => ':ALL')
    or is_URL (($_ -> [1] =~ /^[Vv][Ii][Ee][Ww]-[Ss][Oo][Uu][Rr][Cc][Ee]:(.+)/)[0] || '' => 'http')
    or (  $_ -> [1] =~ m<^(?:\.?\.?/(?!/)|\?)>
      and is_URL (rel_uri ($_ -> [1], $base) => 'http'))
  } @rawlinks;

  # collect all [image:...] strings
  #
  my @rawimages;
  push @rawimages => [$1 => $2] while ($posting =~ /\[([Ii][Mm][Aa][Gg][Ee]):\s*([^\]\s]+)\s*\]/g);
  my @images = grep {
       is_URL ($_ -> [1] => 'strict_http')
    or (  $_ -> [1] =~ m<^(?:\.?\.?/(?!/)|\?)>
      and is_URL (rel_uri ($_ -> [1], $base) => 'http'))
  } @rawimages;

  # collect all [iframe:...] strings
  #
  my @rawiframes;
  push @rawiframes => [$1 => $2] while ($posting =~ /\[([Ii][Ff][Rr][Aa][Mm][Ee]):\s*([^\]\s]+)\s*\]/g);
  my @iframes = grep {
       is_URL ($_ -> [1] => 'http')
    or (  $_ -> [1] =~ m<^(?:\.?\.?/(?!/)|\?)>
      and is_URL (rel_uri ($_ -> [1], $base) => 'http'))
  } @rawiframes;

  # collect all [msg:...] strings
  #
  $params -> {messages} = {} unless (defined $params -> {messages});
  my %msg = map {lc($_) => $params -> {messages} -> {$_}} keys %{$params -> {messages}};

  my @rawmsgs;
  push @rawmsgs => [$1 => $2] while ($posting =~ /\[([Mm][Ss][Gg]):\s*([^\]\s]+)\s*\]/g);
  my @msgs = grep {exists ($msg{lc($_ -> [1])})} @rawmsgs;

  # encode Entities and special characters
  #
  $posting = ${plain (\$posting)};

  # encode the special syntaxes
  #
  $posting =~ s!$_!<a href="$1">$1</a>!
    for (map {qr/\[\Q${plain(\$_->[0])}\E:\s*(\Q${plain(\$_->[1])}\E)\s*\]/} @links);

  $posting =~ s!$_!<img src="$1" border=0 alt="">!
    for (map {qr/\[\Q${plain(\$_->[0])}\E:\s*(\Q${plain(\$_->[1])}\E)\s*\]/} @images);

  $posting =~ s!$_!<iframe src="$1" width="90%" height="90%"><a href="$1">$1</a></iframe>!
    for (map {qr/\[\Q${plain(\$_->[0])}\E:\s*(\Q${plain(\$_->[1])}\E)\s*\]/} @iframes);

  %msg = map {plain($_) => $msg{$_}} keys %msg;
  $posting =~ s!$_!'<img src="'.$msg{lc $1} -> {src}.'" width='.$msg{lc $1}->{width}.' height='.$msg{lc $1}->{height}.' border=0 alt="'.plain($msg{lc $1}->{alt}).'">'!e
    for (map {qr/\[\Q${plain(\$_->[0])}\E:\s*(\Q${plain(\$_->[1])}\E)\s*\]/} @msgs);

  # normalize quote characters (quote => \177)
  #
  my $quote = plain(defined $params -> {quoteChars} ? $params -> {quoteChars} : '');
  my $len = length ($quote);
  $posting =~ s!^((?:\Q$quote\E)+)!"\177" x (length($1)/$len)!gem if ($len);

  # \n => <br>, fix spaces
  #
  $posting = ${multiline (\$posting)};

  # return
  #
  \$posting;
}

### sub answer_field ($$) ######################################################
#
# create the content of the answer textarea
#
# Params: $posting - scalar reference
#                    (posting text, 'encoded_body' encoded)
#         $params  - hash reference
#                    (quoteArea quoteChars messages)
#
# Return: scalar reference
#
sub answer_field ($$) {
  my $posting = shift;
  my $params = shift || {};

  my $area = $$posting;
  my $qchar = $params -> {quoteChars};

  $area =~ s/<br>/\n/g;            # <br> => \n
  $area =~ s/&(?:#160|nbsp);/ /g;  # nbsp => ' '

  $area =~ s/^(.)/\177$1/gm if ($params -> {quoteArea}); # shift a quoting character
  $area =~ s/^(\177+)/$qchar x length ($1)/gem;          # decode normalized quoting characters

  # recode special syntaxes
  # from HTML to [...] constructions
  #
  $params -> {messages} = {} unless (defined $params -> {messages}); # avoid error messages
  my %msg = map {
    $params -> {messages} -> {$_} -> {src} => $_
  } keys %{$params -> {messages}};                                   # we have to lookup reverse ...

  # [msg...]
  $area =~ s{(<img\s+src="([^"]+)"\s+width[^>]+>)} {
    defined $msg{$2}
    ? "[msg: $msg{$2}]"
    : $1;
  }ge;

  # [iframe...]
  $area =~ s{<iframe\s+src="([^"]*)"[^>]+>.*?</iframe>} {[iframe: $1]}g;

  # [image...]
  $area =~ s{<img src="([^"]*)"[^>]*>}{[image: $1]}g;

  # [link...]
  $area =~ s{<a href="([^"]*)">.*?</a>}{[link: $1]}g;

  # return
  #
  \$area;
}

### sub message_field ($$) #####################################################
#
# prepare the posting text for visual output
#
# Params: $posting - scalar reference
#                    (raw posting text, 'encoded_body' encoded)
#         $params  - hash reference
#                    (quoteChars quoting startCite endCite)
#
# Return: scalar rerence (prepared posting text)
#
sub message_field ($$) {
  my $posting = ${+shift};
  my $params = shift || {};

  my $break = '<br>';

  if ($params -> {quoting}) {       # quotes are displayed as special?
    my @array = [0 => []];

    for (split /<br>/ => $posting) {
      my $l = length ((/^(\177*)/)[0]);
      if ($array[-1][0] == $l) {
        push @{$array[-1][-1]} => $_;
      }
      else {
        push @array => [$l => [$_]];
      }
    }
    shift @array unless @{$array[0][-1]};

    my $ll=0;
    $posting = join '<br>' => map {
      my $string = $_->[0]
        ? (($ll and $ll != $_->[0]) ? $break : '') .
          join join ($break => @{$_->[-1]})
            => ($params->{startCite}, $params->{endCite})
        : (join $break => @{$_->[-1]});
      $ll = $_->[0]; $string;
    } @array;
  }

  my $qchar = $params -> {quoteChars};
  $posting =~ s/\177/$qchar/g; # \177 => quote chars

  # return
  #
  \$posting;
}

# keeping 'require' happy
1;

#
#
### end of Encode::Posting #####################################################