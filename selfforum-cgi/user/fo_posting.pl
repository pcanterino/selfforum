#!/usr/bin/perl -wT

################################################################################
#                                                                              #
# File:        user/fo_posting.pl                                              #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>, 2001-03-31                          #
#                                                                              #
# Description: Accept new postings, display "Neue Nachricht" page              #
#                                                                              #
# not ready, be patient please                                                 #
#                                                                              #
################################################################################

use strict;
use vars qw($Bin $Shared $Script);

# locate the script
BEGIN {
  my $null = $0; $null =~ s/\\/\//g; # for win :-(
  ($Bin)    = ($null =~ /^(.*)\/.*$/)? $1 : '.';
  $Shared   = "$Bin/../shared";
  ($Script) = ($null =~ /^.*\/(.*)$/)? $1 : $null;
}

use lib "$Shared";
use CGI::Carp qw(fatalsToBrowser);

#use Conf;
#use Encode::Plain; $Encode::Plain::utf8 = 1; # generally convert from UTF-8
#use Id;
#use Posting::Write;
#use Template;
#use Template::Posting;

#use autouse 'Encode::Posting' => qw();

# load script configuration and admin default conf.
my $conf         = read_script_conf ($Bin, $Shared, $Script);
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

#
#
### main end ###################################################################

################################################################################
### Posting::Request ###########################################################
package Posting::Request;

use Lock          qw(:ALL);
use Posting::_lib qw(
      hr_time
      parse_xml_file
      get_all_threads get_message_node get_message_header
      KEEP_DELETED
    );

use autouse 'CheckRFC' => qw[ is_email($) is_URL($@) ];
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

  # lock and load the forum main file
  #
  if ($self -> load_main_file) {

    # if a reply - is it legal?
    # is it a dupe?
    #
    if ($self -> check_reply_dupe) {

      # we've got an opening
      #
      if ($self -> {response} -> {new}) {
        $self -> save_new;
      }

      # we've got a reply
      #
      elsif ($self -> {response} -> {reply}) {
        $self -> save_reply;
      }

      # don't know, if we any time come to this branch
      # the script is probably broken
      #
      else {
        $self -> {error} = {
          spec => 'unknown_error',
          type => 'fatal'
        };
      }
    }
  }

  # unlock forum main file
  #
  if ($self -> {forum} -> {flocked}) {
    violent_unlock_file($self -> {forum_file_name}) unless unlock_file ($self -> {forum_file_name});
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
  my $q = new CGI;
  $self -> {cgi_object} = $q;

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
  my $lock_stat;

  unless ($lock_stat = write_lock_file ($self ->{forum_file_name})) {
    if ($lock_stat == 0) {
      # occupied or no w-bit set for the directory..., hmmm
      #
      violent_unlock_file ($self -> {forum_file_name});
      $self -> {error} = {
        spec => 'occupied',
        type => 'fatal'
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
    $self -> {forum} -> {flocked} = 1;
    ( $self -> {forum} -> {threads},
      $self -> {forum} -> {last_thread},
      $self -> {forum} -> {last_message},
      undef,
      $self -> {forum} -> {unids}
    ) = get_all_threads ($self -> {forum_file_name}, KEEP_DELETED);
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

  # return true unless it's not a reply
  #
  return 1 unless (
    $self -> {response} -> {reply}
    and $self -> {response} -> {new}
  );

  my %unids;

  if ($self -> {response} -> {reply}) {

    my ($threads, $ftid, $fmid, $i, %msg, %unids) = (
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
    %unids = map {$_ => 1} @{$self -> {unids}};
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
  my %name = map {($formdata -> {$_} -> {name} => $_)} keys %$formdata;

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
           $self -> {response} -> {new}
        or $formdata -> {$name {$_}} -> {errorType} eq 'fetch') {

        $self -> {error} = {
          spec => 'missing_key',
          type => 'fatal'
        };
        return;
      }
      else {
        # keep in mind to fetch the value later
        #
        push @{$self -> {fetch}} => $name {$_};
      }
    }
  }

  # 3
  #
  for ($self -> {cgi_object} -> param) {
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

  # I'm lazy - I know...
  my $q = $self -> {cgi_object};

  if ($self -> {response} -> {reply}) {

    # get the parent-identifiers if we got a reply request
    #
    my ($ftid, $fmid) = split /;/ => $q -> param ($formdata -> {followUp} -> {name}) => 2;

    unless ($ftid =~ /\d+/ and $fmid =~ /\d+/) {
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
    $got_keys{$_}=1 for (@{$self -> {fetch}});
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
      return;
    }

    # too short?
    # (only check if there's defined a minimum length)
    #
    if (exists ($formdata -> {$name {$_}} -> {minlength})) {

      # kill the whitespaces to get only the visible characters...
      #
      (my $val_ww = $val) =~ s/\s+//g;

      if (length $val_ww < $formdata -> {$name {$_}} -> {minlength}) {
        $self -> {error} = {
          spec => 'too_short',
          desc => $name{$_},
          type => $formdata -> {$name {$_}} -> {errorType}
        };
        return;
      }
    }

    # check the values on expected kinds of content
    # (email, http-url, url)
    #
    if (exists ($formdata -> {$name {$_}} -> {type}) and length $val) {
      if ($formdata -> {$name {$_}} -> {type} eq 'email' and not is_email $val) {
        $self -> {error} = {
          spec => 'wrong_mail',
          desc => $name{$_},
          type => $formdata -> {$name {$_}} -> {errorType}
        };
        return;
      }

      elsif ($formdata -> {$name {$_}} -> {type} eq 'http-url' and not is_URL $val => 'http') {
        $self -> {error} = {
          spec => 'wrong_http_url',
          desc => $name{$_},
          type => $formdata -> {$name {$_}} -> {errorType}
        };
        return;
      }

      elsif ($formdata -> {$name {$_}} -> {type} eq 'url' and not is_URL $val => ':ALL') {
        $self -> {error} = {
          spec => 'wrong_url',
          desc => $name{$_},
          type => $formdata -> {$name {$_}} -> {errorType}
        };
        return;
      }
    }
  }

  # ok, looks good.
  1;
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
    my $filename = $self -> {conf} -> {message_path}.'t'.$self -> {fup_tid}.'.xml';

    if (lock_file ($filename)) {
      my $xml = parse_xml_file ($filename);
      violent_unlock_file($filename) unless unlock_file ($filename);

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
  $q -> param ($formdata -> {quoteChar} -> {name} => substr ($code, 2));

  # ok, params now should be UTF-8 encoded
  1;
}

#
#
### end of fo_posting.pl #######################################################