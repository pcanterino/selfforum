#!/usr/bin/perl -w

################################################################################
#                                                                              #
# File:        user/fo_posting.pl                                              #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>, 2001-04-08                          #
#                                                                              #
# Description: Accept new postings, display "Neue Nachricht" page              #
#                                                                              #
################################################################################

use strict;
use vars qw(
  $Bin
  $Shared
  $Script
  $Config
  $VERSION
);

# locate the script
#
BEGIN {
  my $null = $0; $null =~ s/\\/\//g; # for win :-(
  $Bin     = ($null =~ /^(.*)\/.*$/)? $1 : '.';
  $Shared  = "$Bin/../shared";
  $Config  = "$Bin/config";
  $Script  = ($null =~ /^.*\/(.*)$/)? $1 : $null;

#  my $null = $0;
#  $Bin     = ($null =~ /^(.*)\/.*$/)? $1 : '.';
#  $Config  = "$Bin/../../daten/forum/config";
#  $Shared  = "$Bin/../../cgi-shared";
#  $Script  = ($null =~ /^.*\/(.*)$/)? $1 : $null;
}

# setting umask, remove or comment it, if you don't need
#
umask 006;

use lib "$Shared";
use CGI::Carp qw(fatalsToBrowser);

use Conf;
use Conf::Admin;
use Posting::Cache;

# Version check
#
$VERSION = do { my @r =(q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

# load script configuration and admin default conf.
#
my $conf         = read_script_conf ($Config, $Shared, $Script);
my $adminDefault = read_admin_conf ($conf -> {files} -> {adminDefault});

# Initialize the request
#
my $request = new Posting::Request ($conf, $adminDefault);

# fetch and parse the cgi-params
#
$request -> parse_cgi;

# handle errors or save the posting
#
$request -> handle_error or $request -> save;

# show response
#
$request -> response;

# shorten the main file?
#
$request -> severance;

#
#
### main end ###################################################################

################################################################################
### Posting::Request ###########################################################
package Posting::Request;

use Arc::Archive;
use CheckRFC;
use Encode::Plain; $Encode::Plain::utf8 = 1; # generally convert from UTF-8
use Encode::Posting;
use Lock;
use Posting::_lib qw(
  hr_time
  parse_xml_file
  get_all_threads
  get_message_node
  get_message_header
  KEEP_DELETED
);
use Posting::Write;
use Id;
use Template;
use Template::Posting;

use CGI;

### sub new ####################################################################
#
# initialising the Posting::Request object
# check parameters and fill in object properties
#
sub new {
  my ($class, $conf, $adminDefault) = @_;

  my $sp = $conf -> {show} -> {Posting};

  my $self = {
       conf => {
         original => $conf,
         admin    => $adminDefault,

         message_path    => $conf -> {files} -> {messagePath},
         forum_file_name => $conf -> {files} -> {forum},

         show_posting    => $sp,
         assign          => $sp -> {assign},
         template        => $conf -> {template},
         form_must       => $sp -> {form} -> {must},
         form_data       => $sp -> {form} -> {data},
         form_action     => $sp -> {form} -> {action},
       },

       template => new Template $sp -> {templateFile},
       response => {},
       forum    => {},
       error    => {}
     };

  bless $self, $class;
}

sub severance {
  my $self = shift;

  my $stat = cut_tail ({
    forumFile    => $self -> {conf} -> {forum_file_name},
    messagePath  => $self -> {conf} -> {message_path},
    archivePath  => $self -> {conf} -> {original} -> {files} -> {archivePath},
    lockFile     => $self -> {conf} -> {original} -> {files} -> {sev_lock},
    adminDefault => $self -> {conf} -> {admin},
    cachePath    => $self -> {conf} -> {original} -> {files} -> {cachePath}
  });
#  die $stat->{(keys %$stat)[0]} if (%$stat);

}

### sub response ###############################################################
#
# print the response to STDOUT
#
# Return: -none-
#
sub response {
  my $self = shift;
  my $formdata = $self -> {conf} -> {form_data};
  my $formact  = $self -> {conf} -> {form_action};
  my $template = $self -> {template};
  my $assign   = $self -> {conf} -> {assign};
  my $q        = $self -> {cgi_object};

  # fill out the form field names
  #
  my $pars = {};
  for (keys %$formdata) {
    $pars -> {$formdata -> {$_} -> {assign} -> {name}} = plain($formdata -> {$_} -> {name}) if (
      exists($formdata -> {$_} -> {name})
      and exists ($formdata -> {$_} -> {assign})
      and exists ($formdata -> {$_} -> {assign} -> {name})
    );
  }

  # response the 'new message' page
  #
  if ($self -> {response} -> {new_thread}) {

    # fill in the default form data
    # and optionlist(s)
    #
    my $default = {};
    for (keys %$formdata) {
      unless (exists ($formdata -> {$_} -> {type}) and $formdata -> {$_} -> {type} eq 'internal') {
        if (exists ($formdata -> {$_} -> {default}) and exists ($formdata -> {$_} -> {assign} -> {value})) {
          $default -> {$formdata -> {$_} -> {assign} -> {value}}
          = $formdata -> {$_} -> {default};
        }
        elsif (exists($formdata -> {$_} -> {values})) {
          my ($_name, $val) = $_;
          $val = exists ($formdata -> {$_} -> {default})
            ? $formdata -> {$_} -> {default}
            : undef;
          $default -> {$formdata -> {$_} -> {assign} -> {value}}
          = $self -> {template} -> list (
              $assign -> {option},
              [ map {
                  { $assign -> {optval} => plain($_),
                    ((defined $val and $_ eq $val)
                      ? ($assign -> {optsel} => 1)
                      : ()
                    )
                  }
                } @{$formdata -> {$_name} -> {values}}
              ]
            );
        }
      }
    }

    print $q -> header (-type => 'text/html');
    print ${$template -> scrap (
      $assign -> {docNew},
      { $formdata->{uniqueID}      ->{assign}->{value} => plain(unique_id),
        $formdata->{quoteChar}     ->{assign}->{value} => '&#255;'.plain($self -> {conf} -> {admin} -> {View} -> {quoteChars}),
        $formact->{post}->{assign}                     => $formact->{post}->{url},
      },
      $pars,
      $default
    )};
    return;
  }

  # check the response -> doc
  #
  unless ($self -> {response} -> {doc}) {
    $self -> {error} = {
      spec => 'unknown_error',
      type => 'fatal'
    };

    $self -> handle_error;

    unless ($self -> {response} -> {doc}) {
      $self -> jerk ('While producing the HTML response an unknown error has occurred.');
      return;
    }
  }

  # ok, print the response document to STDOUT
  #
  print $q -> header (-type => 'text/html');
  print ${$template -> scrap (
      $self -> {response} -> {doc},
      $pars,
      $self -> {response} -> {pars}
    )
  };

  return;
}

### sub handle_error ###########################################################
#
# analyze error data and create content for the response method
#
# Return: true  if error detected
#         false otherwise
#
sub handle_error {
  my $self = shift;

  my $spec = $self -> {error} -> {spec};

  return unless ($spec);

  my $assign   = $self -> {conf} -> {assign};
  my $formdata = $self -> {conf} -> {form_data};

  my $desc = $self -> {error} -> {desc} || '';
  my $type = $self -> {error} -> {type};
  my $emsg;

  if (exists ($formdata -> {$desc})
      and exists ($formdata -> {$desc} -> {assign} -> {$spec})) {
    $emsg = $formdata -> {$desc} -> {assign} -> {$spec};
  }
  else {
    $emsg = $assign -> {$spec} || '';
  }

  # fatal errors
  #
  if ($type eq 'fatal') {
    $self -> {response} -> {doc}  = $assign -> {docFatal};
    $self -> {response} -> {pars} = {
      $assign -> {errorMessage} => $self -> {template} -> insert ($emsg)
    };
  }

  # 'soft' errors
  # user is able to repair his request
  #
  elsif ($type eq 'repeat' or $type eq 'fetch') {
    $self -> {response} -> {doc} = $assign -> {docError};
    $self -> fillout_form;
    $self -> {response} -> {pars} -> {$assign -> {errorMessage}} = $self -> {template} -> insert ($emsg);
    my $num = $spec eq 'too_long'
      ? $formdata -> {$desc} -> {maxlength}
      : ($spec eq 'too_short'
          ? $formdata -> {$desc} -> {minlength}
          : undef
        );

    $self -> {response} -> {pars} -> {$assign -> {charNum}} = $num
      if $num;
  }

  1;
}

### sub fillout_form ###########################################################
#
# fill out the form using available form data
#
# Return: -none-
#
sub fillout_form {
  my $self = shift;

  my $assign   = $self -> {conf} -> {assign};
  my $formdata = $self -> {conf} -> {form_data};
  my $formact  = $self -> {conf} -> {form_action};
  my $q        = $self -> {cgi_object};
  my $pars     = {};

  # fill out the form
  #
  $pars -> {$formact -> {post} -> {assign}} = $formact -> {post} -> {url};

  for (keys %$formdata) {
    if ($_ eq 'quoteChar') {
      $pars -> {$formdata->{$_}->{assign}->{value}}
      = '&#255;'.plain($q -> param ($formdata -> {quoteChar} -> {name}) or '');
    }
    elsif (exists ($formdata -> {$_} -> {name})) {
      unless (exists ($formdata -> {$_} -> {values})) {
        $pars -> {$formdata -> {$_} -> {assign} -> {value}}
        = plain($q -> param ($formdata -> {$_} -> {name}));
      }
      else {
        my $_name = $_;
        $pars -> {$formdata -> {$_} -> {assign} -> {value}}
        = $self -> {template} -> list (
            $assign -> {option},
            [ map {
                { $assign -> {optval} => plain($_),
                  (( $_ eq $q -> param ($formdata -> {$_name} -> {name}))
                    ? ($assign -> {optsel} => 1)
                    : ()
                  )
                }
              } @{$formdata -> {$_name} -> {values}}
            ]
          );
      }
    }
  }

  $self -> {response} -> {pars} = $pars;
  return;
}

### sub save ###################################################################
#
# save posting
# check on legal reply or dupe is released here
#
# Return: -none-
#
sub save {
  my $self = shift;

  # if an empty 'new message' document, there's nothing to save
  #
  return if ($self -> {response} -> {new_thread});

  $self -> {check_success} = 0;

  # lock and load the forum main file
  #
  if ($self -> load_main_file) {

    # if a reply - is it legal?
    # is it a dupe?
    #
    if ($self -> check_reply_dupe) {

      unless ($self -> {response} -> {reply} or $self -> {response} -> {new}) {
        # don't know, if we any time come to this branch
        # the script is probably broken
        #
        $self -> {error} = {
          spec => 'unknown_error',
          type => 'fatal'
        };
      }
      else {
        my $time     = time;
        my $formdata = $self -> {conf} -> {form_data};
        my $q        = $self -> {cgi_object};
        my $f        = $self -> {forum};
        my $pars     = {
          quoteChars    => $q -> param ($formdata -> {quoteChar} -> {name}),
          uniqueID      => $q -> param ($formdata -> {uniqueID} -> {name}),
          time          => $time,
          ip            => $q -> remote_addr,
          forumFile     => $self -> {conf} -> {forum_file_name},
          messagePath   => $self -> {conf} -> {message_path},
          lastThread    => $f -> {last_thread},
          lastMessage   => $f -> {last_message},
          parsedThreads => $f -> {threads},
          dtd           => $f -> {dtd},
          messages      => $self -> {conf} -> {template} -> {messages} || {},
          base_uri      => $self -> {conf} -> {original} -> {files} -> {forum_base}
        };

        # set the variables if defined..
        #
        my %may = (
          author   => 'posterName',
          email    => 'posterEmail',
          category => 'posterCategory',
          subject  => 'posterSubject',
          body     => 'posterBody',
          homepage => 'posterURL',
          image    => 'posterImage'
        );

        for (keys %may) {
          $pars -> {$_} = $q -> param ($formdata -> {$may{$_}} -> {name})
            if (defined $q -> param ($formdata -> {$may{$_}} -> {name}));
        }

        my ($stat, $xml, $mid, $tid);

        # we've got a fup if it's a reply
        #
        if ($self -> {response} -> {reply}) {
          $pars -> {parentMessage} = $self -> {fup_mid};
          $pars -> {thread}        = $self -> {fup_tid};
          ($stat, $xml, $mid, $tid) = write_reply_posting ($pars);
        }
        else {
          ($stat, $xml, $mid, $tid) = write_new_thread ($pars);
        }

        if ($stat) {
          $self -> {error} = {
            spec => 'not_saved',
            desc => $stat,
            type => 'fatal'
          };
        }
        else {
          my $cache = new Posting::Cache ($self->{conf}->{original}->{files}->{cachePath});
          $cache -> add_posting (
            { thread  => ($tid =~ /(\d+)/)[0],
              posting => ($mid =~ /(\d+)/)[0]
            }
          );

          $self -> {check_success} = 1;
          my $thx = $self -> {conf} -> {show_posting} -> {thanx};

          # define special response data
          #
          $self -> {response} -> {doc}  = $self -> {conf} -> {assign} -> {docThx};
          $self -> {response} -> {pars} = {
            $thx -> {time} => plain (hr_time($time)),
            $thx -> {body} => message_as_HTML (
              $xml,
              $self -> {template},
              { posting    => $mid,
                assign     => $self -> {conf} -> {assign},
                quoteChars => $q -> param ($formdata -> {quoteChar} -> {name}),
                quoting    => $self -> {conf} -> {admin} -> {View} -> {quoting}
              }) || ''
          };

          # set the variables if defined..
          #
          my %may = (
            author   => 'posterName',
            email    => 'posterEmail',
            category => 'posterCategory',
            subject  => 'posterSubject',
            homepage => 'posterURL',
            image    => 'posterImage'
          );

          for (keys %may) {
            my $x = $q -> param ($formdata -> {$may{$_}} -> {name});
            $x = '' unless (defined $x);
            $self -> {response} -> {pars} -> {$thx -> {$_}} = plain ($x)
              if (defined $thx -> {$_});
          }
        }
      }
    }
  }

  # unlock forum main file
  #
  if ($self -> {forum} -> {flocked}) {
    $self -> {forum} -> {flocked} -> unlock;
    $self -> {forum} -> {flocked} = 0;
  }

  $self -> handle_error unless $self -> {check_success};

  return;
}

### sub parse_cgi ##############################################################
#
# fetch and decode cgi-parameters,
# find out the kind of response requested by the user (new message, reply)
#
# Return: -none-
#
sub parse_cgi {
  my $self = shift;

  # create the CGI object
  #
  $self -> {cgi_object} = new CGI;

  # check the params
  #
  $self -> {check_success} = $self -> check_cgi;

  return;
}

### sub load_main_file #########################################################
#
# load and parse the forum main file
#
# Return: Success (true/false)
#
sub load_main_file {
  my $self = shift;
  my $forum = new Lock ($self -> {conf} -> {forum_file_name});

  unless ($forum -> lock(LH_EXCL)) {
    unless ($forum -> masterlocked) {
      # occupied or no w-bit set for the directory..., hmmm
      #
      $self -> {error} = {
        spec => 'occupied',
        type => 'repeat'
      };
      return;
    }
    else {
      # master lock is set
      #
      $self -> {error} = {
        spec => 'master_lock',
        type => 'fatal'
      };
      return;
    }
  }
  else {
    $self -> {forum} -> {flocked} = $forum;
    ( $self -> {forum} -> {threads},
      $self -> {forum} -> {last_thread},
      $self -> {forum} -> {last_message},
      $self -> {forum} -> {dtd},
      $self -> {forum} -> {unids}
    ) = get_all_threads ($self -> {conf} -> {forum_file_name}, KEEP_DELETED);
  }

  # ok, looks good
  1;
}

### sub check_reply_dupe #######################################################
#
# check whether a reply is legal
# (followup posting must exists)
#
# check whether this form request is a dupe
# (unique id already exists)
#
# Return: Status Code (Bool)
#
sub check_reply_dupe {
  my $self = shift;
  my %unids;

  # return true unless it's not a reply
  # or an opening
  #
  return 1 unless (
    $self -> {response} -> {reply}
    or $self -> {response} -> {new}
  );

  if ($self -> {response} -> {reply}) {

    my ($threads, $ftid, $fmid, $i, %msg) = (
          $self -> {forum} -> {threads},
          $self -> {fup_tid},
          $self -> {fup_mid}
       );

    # thread doesn't exist
    #
    unless (exists($threads -> {$ftid})) {
      $self -> {error} = {
        spec => 'no_reply',
        type => 'fatal'
      };
      return;
    }

    # build a reverse lookup hash (mid => number in array)
    # and ignore invisible messages
    # (users can't reply to "deleted" msg)
    #
    for ($i=0; $i < @{$threads -> {$ftid}}; $i++) {

      if ($threads -> {$ftid} -> [$i] -> {deleted}) {
        $i+=$threads -> {$ftid} -> [$i] -> {answers};
      }
      else {
        $msg{$threads -> {$ftid} -> [$i] -> {mid}}=$i;
      }
    }

    # message doesn't exist
    #
    unless (exists($msg{$fmid})) {
      $self -> {error} = {
        spec => 'no_reply',
        type => 'fatal'
      };
      return;
    }

    # build a unique id lookup hash
    # use the unids of parent message's kids
    #
    %unids = map {$_ => 1} @{$threads -> {$ftid} -> [$msg{$fmid}] -> {unids}};
  }
  else {
    # build a unique id lookup hash, too
    # but use only the level-zero-messages
    #
    %unids = map {$_ => 1} @{$self -> {forum} -> {unids}};
  }

  # now check on dupe
  #
  if (exists ($unids{
                $self -> {cgi_object} -> param (
                  $self -> {conf} -> {form_data} -> {uniqueID} -> {name})})) {
    $self -> {error} = {
      spec => 'dupe',
      type => 'fatal'
    };
    return;
  }

  # ok, looks fine
  1;
}

### sub check_cgi ##############################################################
#
# cgi params are like raw eggs...
#
# Return: Status Code (Bool)
#         creates content for the handle_error method if anything fails
#
sub check_cgi {
  my $self = shift;

  # count the submitted keys and get the keys themselves
  #
  my %got_keys     = map {($_ => 1)} $self -> {cgi_object} -> param;
  my $cnt_got_keys = keys %got_keys;
  my $formdata     = $self -> {conf} -> {form_data};
  my $formmust     = $self -> {conf} -> {form_must};

  # user requested the 'new thread' page
  # (no params but perhaps the user-ID have been submitted)
  #
  if ($cnt_got_keys == 0 or (
        exists ($formdata -> {userID})
        and $cnt_got_keys == 1
        and $got_keys{$formdata -> {userID} -> {name}}
        )) {
    $self -> {response} -> {new_thread} = 1;
    $self -> {check_success} = 1;
    return 1;
  }

  # now we know, we've got a filled out form
  # we do the following steps to check it:
  #
  # 1st: create a reverse Hash (CGI-key - identifier)
  # 2nd: did we get _all_ must-keys?
  #      check whether reply or new message request
  # 3rd: did we get too many keys?
  # 4th: do _all_ submitted values accord to
  #      our expectations?
  #      fetch the "missing" keys
  #

  # 1
  #
  my %name = map {
    exists($formdata -> {$_} -> {name})
    ? ($formdata -> {$_} -> {name} => $_)
    : ()
  } keys %$formdata;

  # 2
  #
  $self -> {response} -> {reply} = $got_keys {$formdata -> {followUp} -> {name}}? 1 : 0;
  $self -> {response} -> {new}   = not $self -> {response} -> {reply};

  # define the fetch array (values to fetch from parent message)
  #
  $self -> {fetch} = [];

  for ( @{$formmust -> {$self -> {response} -> {reply}?'reply':'new'}} ) {

    unless ($got_keys {$formdata -> {$_} -> {name}}) {

      # only miss the key unless we're able to fetch it from parent posting
      #
      unless (
        not $self -> {response} -> {reply}
        or $formdata -> {$_} -> {errorType} eq 'fetch') {

        $self -> {error} = {
          spec => 'missing_key',
          desc => $_,
          type => 'fatal'
        };
        return;
      }
      else {
        # keep in mind to fetch the value later
        #
        push @{$self -> {fetch}} => $_;
      }
    }
  }

  # I'm lazy - I know...
  my $q = $self -> {cgi_object};

  # 3
  #
  for ($q -> param) {
    unless (exists ($name {$_})) {
      $self -> {error} = {
        spec => 'unexpected_key',
        desc => $name{$_},
        type => 'fatal'
      };
      return;
    }
  }

  # 4
  #
  unless ($self -> decode_param) {
    $self -> {error} = {
      spec => 'unknown_encoding',
      type => 'fatal'
    };
    return;
  };

  if ($self -> {response} -> {reply}) {

    # get the parent-identifiers if we got a reply request
    #
    my ($ftid, $fmid) = split /;/ => $q -> param ($formdata -> {followUp} -> {name}) => 2;

    unless ($ftid =~ /^\d+$/ and $fmid =~ /^\d+$/) {
      $self -> {error} = {
        spec => 'unknown_followup',
        type => 'fatal'
      };
      return;
    }
    $self -> {fup_tid} = $ftid;
    $self -> {fup_mid} = $fmid;

    # fetch the missing keys
    # if it fails, they're too short, too... ;)
    #
    $self -> fetch;
    $got_keys{$formdata -> {$_} -> {name}} = 1 for (@{$self -> {fetch}});
  }

  # now we can check on length, type etc.
  #
  for (keys %got_keys) {

    # we are sure, we've got only one value for one key
    #
    my $val = $q -> param ($_);

    $val =~ s/\302\240/ /g;           # convert nbsp (UTF-8 encoded) into normal spaces
    $val =~ s/\015\012|\015|\012/ /g  # convert \n into spaces unless it's a multiline field
      unless (
        exists ($formdata -> {$name {$_}} -> {type})
        and $formdata -> {$name {$_}} -> {type} eq 'multiline-text'
      );

    $q -> param ($_ => $val);  # write it back

    # too long?
    #
    if (length $val > $formdata -> {$name {$_}} -> {maxlength}) {
      $self -> {error} = {
        spec => 'too_long',
        desc => $name{$_},
        type => $formdata -> {$name {$_}} -> {errorType}
      };
      $self -> kill_param or return;
    }

    # too short?
    # (only check if there's defined a minimum length)
    #
    if (exists ($formdata -> {$name {$_}} -> {minlength})) {

      # kill the whitespaces to get only the visible characters...
      #
      (my $val_ww = $val) =~ s/\s+//g;

      if (exists ($formdata -> {$name {$_}} -> {type}) and $formdata -> {$name {$_}} -> {type} eq 'name') {
        $val_ww =~ y/a-zA-Z//cd;

        my @badlist;
#        my @badlist = map {qr/\Q$_/i} qw (
#          # insert badmatchlist here
#        );

#        push @badlist => map {qr/\b\Q$_\E\b/i} qw(
#          # insert badwordlist here
#        );

        for (@badlist) {
          if ($val_ww =~ /$_/) {
            $self -> {error} = {
              spec => 'undesired',
              desc => $name{$_},
              type => 'fatal'
            };
            return;
          }
        }
      }

      if (length $val_ww < $formdata -> {$name {$_}} -> {minlength}) {
        $self -> {error} = {
          spec => 'too_short',
          desc => $name{$_},
          type => $formdata -> {$name {$_}} -> {errorType}
        };
        $self -> kill_param or return;
      }
    }

    # check the values on expected kinds of content
    # (email, http-url, url, option)
    #
    if (exists ($formdata -> {$name {$_}} -> {type}) and length $val) {
      if ($formdata -> {$name {$_}} -> {type} eq 'email' and not is_email $val) {
        $self -> {error} = {
          spec => 'wrong_mail',
          desc => $name{$_},
          type => $formdata -> {$name {$_}} -> {errorType}
        };
        $self -> kill_param or return;
      }

      elsif ($formdata -> {$name {$_}} -> {type} eq 'http-url' and not is_URL $val => 'http') {
        $self -> {error} = {
          spec => 'wrong_http_url',
          desc => $name{$_},
          type => $formdata -> {$name {$_}} -> {errorType}
        };
        $self -> kill_param or return;
      }

      elsif ($formdata -> {$name {$_}} -> {type} eq 'url' and not is_URL $val => ':ALL') {
        $self -> {error} = {
          spec => 'wrong_url',
          desc => $name{$_},
          type => $formdata -> {$name {$_}} -> {errorType}
        };
        $self -> kill_param or return;
      }

      elsif ($formdata -> {$name {$_}} -> {type} eq 'unique-id' and not may_id $val) {
        $self -> {error} = {
          spec => 'wrong_unique_id',
          desc => $name{$_},
          type => $formdata -> {$name {$_}} -> {errorType}
        };
          print STDERR "Manipuliert!";
        $self -> kill_param or return;
      }
    }

    if (exists ($formdata -> {$name {$_}} -> {values})
        and not exists ({map {$_ => undef} @{$formdata -> {$name {$_}} -> {values}}} -> {$val})) {
        $self -> {error} = {
          spec => 'no_option',
          desc => $name{$_},
          type => $formdata -> {$name {$_}} -> {errorType}
        };
        $self -> kill_param or return;
    }
  }

  # ok, looks good.
  1;
}
### sub kill_param #############################################################
#
# kill the param (set it on '') if wrong and declared as 'kill' in config file
#
# Return: true  if killed
#         false otherwise
#
sub kill_param {
  my $self = shift;

  if ($self -> {conf} -> {form_data} -> {$self -> {error} -> {desc}} -> {errorType} eq 'kill') {
    $self -> {cgi_object} -> param ($self -> {conf} -> {form_data} -> {$self -> {error} -> {desc}} -> {name} => '');
    $self -> {error} = {};
    return 1;
  }

  return;
}

### sub fetch ##################################################################
#
# fetch "missing" keys from parent posting
#
sub fetch {
  my $self = shift;
  my $q = $self -> {cgi_object};
  my $formdata = $self -> {conf} -> {form_data};

  if (@{$self -> {fetch}}) {
    my $thread = new Lock ($self -> {conf} -> {message_path}.'t'.$self -> {fup_tid}.'.xml');

    if ($thread -> lock (LH_SHARED)) {
      my $xml = parse_xml_file ($thread -> filename);
      $thread -> unlock;

      if ($xml) {
        my $mnode = get_message_node ($xml, 't'.$self -> {fup_tid}, 'm'.$self -> {fup_mid});
        if ($mnode) {
          my $header = get_message_header ($mnode);

          $q -> param ($formdata -> {$_} -> {name} => $header -> {$formdata -> {$_} -> {header}})
            for (@{$self -> {fetch}});

          return;
        }
      }
    }
  }

  # fetching failed:
  # fillout the values with an empty string
  #
  $q -> param ($formdata -> {$_} -> {name} => '')
    for (@{$self -> {fetch}});

  return;
}

### sub decode_param ###########################################################
#
# convert submitted form data into UTF-8
# unless it's not encoded yet
#
# Return: Status Code (Bool)
#         false if unknown encoding (like UTF-7 for instance)
#
sub decode_param {
  my $self = shift;

  my $q = $self -> {cgi_object};
  my $formdata = $self -> {conf} -> {form_data};

  my $code = $q -> param ($formdata -> {quoteChar} -> {name});
  my @array;

  # Latin 1 (we hope so - there's no real way to find out :-( )
  if ($code =~ /^\377/) {
    $q -> param ($_ => map {toUTF8($_)} $q -> param ($_)) for ($q -> param);
  }
  else {
    # UTF-8 is (probably) correct,
    # other encodings we don't know and fail
    return unless $code =~ /^\303\277/;
  }

  # remove the &#255; (encoded as UTF-8) from quotechars
  $q -> param ($formdata -> {quoteChar} -> {name}
        => substr $q -> param ($formdata -> {quoteChar} -> {name}),2);

  # ok, params now should be UTF-8 encoded
  1;
}

sub jerk {
  my $text = $_[1] || 'An error has occurred.';
  print <<EOF;
Content-type: text/plain



 Oops.

 $text
 We will fix it as soon as possible. Thank you for your patience.

 Regards
    n.d.p.
EOF
}

#
#
### end of fo_posting.pl #######################################################