package Template;

################################################################################
#                                                                              #
# File:        shared/Template.pm                                              #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>, 2001-04-12                          #
#              Frank Schoenmann <fs@tower.de>, 2001-06-04                      #
#                                                                              #
# Description: Handle XML based HTML-Templates                                 #
#                                                                              #
################################################################################

use strict;
use vars qw(
  $xml_dom_used
  $VERSION
);

use Carp qw(
  croak
  confess
);

BEGIN {
  $xml_dom_used = eval q[
    local $SIG{__DIE__};
    use XML::DOM;
    1;
  ];
}

################################################################################
#
# Version check
#
$VERSION = do { my @r =(q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };


### sub new ####################################################################
#
# constructor
#
# Params: ~none~
#
# Return: Template object
#
sub new {
  my $instance = shift;

  my $self = bless {} => ref($instance) || $instance;

  $self -> file (+shift);

  # return
  $self;
}

### sub file ###################################################################
#
# assign new template file to object
# parse the template file
#
# Params: $new - (optional) new template file
#
# Return: scalar - old filename or if there's no old filename given
#
sub file {
  my $self = shift;
  my $new  = shift;
  my $old  = $self -> {file};

  $self -> {file} = $new if (defined $new);
  $self -> parse_file;

  # return
  $old;
}

### sub insert #################################################################
#
# return the placeholder surrounded by meta delimiters
#
# Params: $name - name of placeholder
#
# Return: scalar - placeholder surrounded by meta delimiters
#
sub insert {
  my $self = shift;
  my $name = shift;

  croak "no template file specified"
    unless (defined $self -> {file});

  # return
  $self -> {metaon} . $name . $self -> {metaoff};
}

### sub list ###################################################################
#
# fill in a complete list
#
# Params: $name  - name of the atomic scrap
#         $array - list of hashes (same strcuture like the hash used by 'scrap')
#
# Return: scalar reference - filled in list
#
sub list {
  my $self = shift;
  my $name = shift;

  croak "no template file specified"
    unless (defined $self -> {file});

#  no warnings 'uninitialized';
  my $list = join '' => map { ${ $self -> scrap ($name, $_) } } @{ +shift };

  # return
  \$list;
}

### sub scrap ##################################################################
#
# fill in a template scrap
#
# Params: $name    name of the scrap
#         ...
#         $no_nl   1 - remove newlines (\n)
#                  0 - do no such thing
#
# Return: scalar reference - filled in scrap
#
sub scrap {
  my $self = shift;
  my $name = shift;

  my $no_nl;
  if (!ref $_[$#_]) {
      $no_nl = pop @_;
  }

  croak "no template file specified"
    unless (defined $self -> {file});

  return \'' unless (defined $name and defined ($self -> {parsed} -> {$name}));

  # fetch parameters
  # (and normalize - save only the references in %params)
  #
  my %params;
  %params = map {
    my $ref = $_;
    map {
      ($_ => (
        ref ($ref -> {$_})
        ? (defined ${$ref -> {$_}} ? $ref -> {$_} : \'')
        : \(defined $ref -> {$_} ? $ref -> {$_} : ''))
      )
    } keys %$ref
  } splice @_;

  # fill in...
  #
  my $scrap = $self -> {parsed} -> {$name};
  my $qmon  = quotemeta $self -> {metaon};
  my $qmoff = quotemeta $self -> {metaoff};

  # ...until we've replaced all placeholders
  #
  1 while (
      $scrap =~ s
      <
        $qmon \s*
        ([_a-zA-Z] \S*)
        \s* $qmoff
      >
      [ (exists ( $params{$1} ) )
        ? ${$params{$1}}
        : ( exists ( $self -> {parsed} -> {$1} )
            ? $self -> {parsed} -> {$1}
            : ''
          );
      ]gex
    );

  # parse conditional blocks
  #
  $self -> parse_if (
    \$scrap,
    \%params
  );

  # remove newlines
  #
  $scrap =~ s/\015\012|\015|\012//g if ($no_nl);

  # return
  \$scrap;
}

### sub parse_file #############################################################
#
# read in and parse template file
#
# Params: ~none~
#
# Return: Status Code (Boolean)
#
sub parse_file {
  my $self = shift;
  my $filename = $self -> {file};

  if ($xml_dom_used) {

    # parse template using XML::DOM
    #
    my $xml = eval {
      local $SIG{__DIE__};
      new XML::DOM::Parser -> parsefile ($filename);
    };
    croak "error while parsing template file '$filename': $@" if ($@);

    my $template = $xml -> getElementsByTagName ('Template', 0) -> item (0);

    # extract meta delimiters
    #
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

    return 1; # looks fine
  }
  else {
    # XML::DOM not available...
    # parse the template using both hands ;)
    #

    my ($xml, $root, $template);
    local (*FILE, $/);

    open FILE, "< $filename" or croak "error while reading template file '$filename': $!";
    $xml = <FILE>;
    close FILE or croak "error while closing template file '$filename' after reading: $!";

    ($root, $template) = ($1, $2) if ($xml =~ m|(<Template\s+[^>"]*(?:"[^"]*"[^>"]*)*>)(.*)</Template\s*>|s);
    croak "error while parsing template file '$filename': missing root element 'Template'"
      unless (defined $root and defined $template);

    # extract meta delimiters
    #
    $self -> {metaon}  = $1 if ($root =~ /\smetaon\s*=\s*"([^"]+)"/);
    $self -> {metaoff} = $1 if ($root =~ /\smetaoff\s*=\s*"([^"]+)"/);

    croak "missing meta defintion(s) in template file '$filename'." unless ($self -> {metaon} and $self -> {metaoff});

    # don't use any other entities than &quot; &apos; &lt; &gt; and &amp;
    # (while using non XML::DOM - version)
    #
    for ('metaon', 'metaoff') {
      $self -> {$_} =~ s/&quot;/"/g;  $self -> {$_} =~ s/&apos;/'/g;
      $self -> {$_} =~ s/&lt;/</g;    $self -> {$_} =~ s/&gt;/>/g;
      $self -> {$_} =~ s/&amp;/&/g;
    }

    $self -> {parsed} = {};
    while ($template =~ m|<Scrap\s+(?:id\s*=\s*"([^"]+)")?\s*>\s*<!\[CDATA\[([^\]]*(?:\](?!\]>)[^\]]*)*)\]\]>\s*</Scrap\s*>|g) {

      my ($name, $content) = ($1, $2);

      croak "Element 'Scrap' requires attribute 'id' in template file '$filename'"
        unless (defined $name and length $name);

      croak "double defined id '$name' in template file '$filename'"
        if (exists ($self -> {parsed} -> {$name}));

      croak "use '/^[_a-zA-Z]\\S*\$/' for 'Scrap'-ids in template file '$filename' (wrong: '$name')"
        unless ($name =~ /^[_a-zA-Z]\S*$/);

      $content =~ s/^\s+//; $content =~ s/\s+$//;
      $self -> {parsed} -> {$name} = $content;
    }

    return 1; # looks fine
  }

  return; # anything failed (??)
}

### sub parse_if ###############################################################
#
# parse conditional blocks
#
# Params: $scrap  - scalar reference of the template scrap
#         $params - hash reference: values from the application
#
# Return: ~none~, ($$scrap will be modified)
#
sub parse_if {
  my $self = shift;
  my ($scrap, $params) = @_;

  my $qmon  = quotemeta $self -> {metaon};
  my $qmoff = quotemeta $self -> {metaoff};

  # the following regex is just not optimized,
  # but it works ;)

  1 while ($$scrap =~ s {
    ($qmon\s*%(?:IF|ELSE)\s+.+?\s*$qmoff.*?) # skip this part
    (?=$qmon\s*%IF\s+.+?\s*$qmoff)           # if %IF or %ELSE are followed by %IF

   |(                                        # $2 starts here
     $qmon\s*%IF\s+(.+?)\s*$qmoff            # %IF
     (.*?)                                   # $4
     (?:
       $qmon\s*%ENDIF\s*$qmoff               # followed by %ENDIF
      |                                      # or
       $qmon\s*%ELSE\s*$qmoff                # %ELSE...
       (.*?)                                 # $5
       $qmon\s*%ENDIF\s*$qmoff               # ...and ENDIF
     )
    )
  }
  { my $ret;
    if ($2) {
      my ($t3, $t4, $t5) = ($3, $4, $5);

      for (split /\s+/,$t3) {
        next unless (
          exists($params->{$_})
          and defined ${$params->{$_}}
          and length ${$params->{$_}}
        );

        $ret = $t4; last;
      }

      $ret = $t5 || '' unless (defined $ret);
    }
    else {
      $ret=$1;
    }

    $ret;
  }gsex);

  return;
}

# keep 'require' happy
1;

#
#
### end of Template ############################################################