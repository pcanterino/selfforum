#!/usr/bin/perl -wT

################################################################################
#                                                                              #
# File:        user/fo_posting.pl                                              #
#                                                                              #
# Authors:     André Malo <nd@o3media.de>, 2001-03-30                          #
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
#use CGI::Carp qw(fatalsToBrowser);

use Conf;
use Encode::Plain; $Encode::Plain::utf8 = 1;
use Encode::Posting;
use Id;
use Lock qw(:ALL);
use CheckRFC;
use Posting::_lib qw(get_all_threads get_message_node get_message_header hr_time parse_xml_file);
use Posting::Write;
use Template;
use Template::Posting;

use CGI;
use XML::DOM;

# load script configuration and admin default conf.
my $conf         = read_script_conf ($Bin, $Shared, $Script);
my $adminDefault = read_admin_conf ($conf -> {files} -> {adminDefault});

# Initializing the request
my $response = new Posting::Response ($conf, $adminDefault);

# fetch and parse the cgi-params
$response -> parse_cgi;


################################################################################
### Posting::Response ##########################################################
package Posting::Response;

### sub new ####################################################################
#
# initialising the Posting::Response object
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

       template => new Template $sp -> {templateFile}
     };

  bless $self, $class;
}

### sub parse_cgi ##############################################################
#
# fetch and decode cgi-parameters,
# find out the kind of response requested by the user (new message, reply)
#
# Return: Status Code (Bool)
#         try out the error method, if false
#
sub parse_cgi {
  my $self = shift;

  # create the CGI object
  my $q = new CGI;
  $self -> {cgi_object} = $q;

  # check the params
  return unless $self -> check_cgi;
}

### sub check_cgi ##############################################################
#
# cgi params are like raw eggs...
#
# Return: Status Code (Bool)
#         creates content for the error method if anything fails
#
sub check_cgi {
  my $self = shift;

  # find out the count of the submitted keys and the keys themselves
  #
  my %got_keys     = map {($_ => 1)} $self -> {cgi_object} -> param;
  my $cnt_got_keys = keys %got_keys;
  my $formdata = $self -> {conf} -> {form_data};
  my $formmust = $self -> {conf} -> {form_must};

  # user requested the 'new thread' page
  # (no params or only the user-ID has been submitted)
  #
  if ($cnt_got_keys == 0 or (
        exists ($formdata -> {userID})
        and $cnt_got_keys == 1
        and $got_keys{$formdata -> {userID} -> {name}}
        )
     ) {
    $self -> {response} = {new_thread => 1};
    return 1;
  }

  ###################################################
  # now we know, we've got a filled out form
  # we do the following steps to check it:
  #
  # 1st: create a reverse Hash (CGI-key - identifier)
  # 2nd: did we get _all_ must-keys?
  #      check whether reply or new message request
  # 3rd: did we get too many keys?
  # 4th: do _all_ requested values accord to
  #      expectations?
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

        $self -> {error} = {spec => 'missing_key'};
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
        desc => $name{$_}
      };
      return;
    }
  }

  # 4
  #
  unless ($self -> decode_param) {
    $self -> {error} = {spec => 'unknown_encoding'};
    return;
  };

  # I'm lazy - I know...
  my $q = $self -> {cgi_object};

  if ($self -> {response} -> {reply}) {

    # get the parent-identifiers if we got a reply
    #
    my ($ftid, $fmid) = split /;/ => $q -> param ($formdata -> {followUp} -> {name}) => 2;

    unless ($ftid =~ /\d+/ and $fmid =~ /\d+/) {
      $self -> {error} = {spec => 'unknown_followup'};
      return;
    }
    $self -> {fup_tid} = $ftid;
    $self -> {fup_mid} = $fmid;

    # now fetching the missing keys
    # if it fails, they're too short, too... ;)
    #
    $self -> fetch;
  }

  # now we can check on length, type etc.
  #
  for (keys %got_keys) {

    my $val = $q -> param ($_);

    $val =~ s/\302\240/ /g;    # convert nbsp to normal spaces
    $q -> param ($_ => $val);  # write it back

    # too long?
    #
    if (length $val > $formdata -> {$name {$_}} -> {maxlength}) {
      $self -> {error} = {
        spec => 'too_long',
        desc => $name{$_}
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
          desc => $name{$_}
        };
        return;
      }
    }

#    return 'wrongMail' if ($formdata -> {$name{$_}} -> {type} eq 'email' and length ($dparam{$_}) and not is_mail_address ($dparam{$_}));
  }

  # ok, looks good.
  1;
}

#  delete $dparam {$formdata -> {posterURL} -> {name}}
#    unless ($dparam {$formdata -> {posterURL} -> {name}} =~ /$httpurl/);
#
#  delete $dparam {$formdata -> {posterImage} -> {name}}
#    unless ($dparam {$formdata -> {posterImage} -> {name}} =~ /$httpurl/);

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
        }
      }
    }
  }

  # fetching failed:
  # fillout the values with an empty string
  #
  $q -> param ($formdata -> {$_} -> {name} => '')
    for (@{$self -> {fetch}});
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