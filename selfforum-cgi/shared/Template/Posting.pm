package Template::Posting;

################################################################################
#                                                                              #
# File:        shared/Template/Posting.pm                                      #
#                                                                              #
# Authors:     Andre Malo       <nd@o3media.de>, 2001-06-16                    #
#                                                                              #
# Description: show HTML formatted posting                                     #
#                                                                              #
################################################################################

use strict;
use vars qw(
  @EXPORT
  $VERSION
);

use Encode::Posting;
use Encode::Plain; $Encode::Plain::utf8 = 1;
use Id;
use Lock;
use Posting::_lib qw(
  get_message_node
  get_message_header
  get_message_body
  parse_single_thread
  parse_xml_file
  hr_time
);
use Posting::Cache;
use Template;
use Template::_conf;
use Template::_query;
use Template::_thread;

use XML::DOM;

################################################################################
#
# Version check
#
$VERSION = do { my @r =(q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

################################################################################
#
# Export
#
use base qw(Exporter);
@EXPORT = qw(
  print_posting_as_HTML
  message_as_HTML
);

### print_posting_as_HTML () ###################################################
#
# print HTML formatted Posting to STDOUT
#
# Params: $threadpath - /path/to/thread_files
#         $tempfile   - template file
#         $param      - Hash-Reference (see doc for details)
#
# Return: -none-
#
sub print_posting_as_HTML ($$$) {
  my ($threadpath, $tempfile, $param) = @_;

  my $template = new Template $tempfile;
  my $assign = $param -> {assign};

  my $view = get_view_params ({
    adminDefault => $param -> {adminDefault}
  });

  my $fh = new Lock ($threadpath.'t'.$param -> {thread}.'.xml');

  unless ($fh -> lock (LH_SHARED)) {
    print ${$template -> scrap (
      $assign -> {errorDoc},
      { $assign -> {errorText} => $template -> insert (
          $assign -> {
            $fh -> masterlocked
            ? 'notAvailable'
            : 'occupied'
          }
        )
      }
    )};
  }
  else {
    unless (-f $fh -> filename) {
      $fh -> unlock;
      print ${$template -> scrap ($assign -> {errorDoc}, {$assign -> {errorText} => $template -> insert ($assign->{notAvailable})})};
    }
    else {
      my $xml = parse_xml_file ($fh -> filename); #...
      $fh -> unlock;

      unless ($xml) {
        print ${$template -> scrap ($assign -> {errorDoc}, {$assign -> {errorText} => $template -> insert ($assign->{corrupt})})};
      }
      else {
        my ($mnode, $tnode) = get_message_node ($xml, 't'.$param -> {thread}, 'm'.$param -> {posting});

        unless ($mnode and not $mnode->getAttribute('invisible')) {
          print ${$template -> scrap (
            $assign -> {errorDoc},
            { $assign -> {errorText} => $template -> insert ($assign -> {'notAvailable'}) }
          )};
        }
        else {
          my $pnode = $mnode -> getParentNode;
          my $header = get_message_header ($mnode);
          my $msg = parse_single_thread ($tnode, $param -> {showDeleted}, $view -> {sortedMsg});
          my $pheader = ($pnode -> getNodeName eq 'Message')?get_message_header ($pnode):{};

          my $formdata = $param -> {form} -> {data};
          my $formact = $param -> {form} -> {action};

          my $body = get_message_body ($xml, 'm'.$param -> {posting});

          my $text = message_field (
            $body,
            { quoteChars => plain($view -> {quoteChars}),
              quoting    => $view -> {quoting},
              startCite  => ${$template -> scrap ($assign -> {startCite})},
              endCite    => ${$template -> scrap ($assign -> {endCite})}
            }
          );

          my $area = answer_field (
            $body,
            { quoteArea  => 1,
              quoteChars => plain($view -> {quoteChars}),
              messages   => $param -> {messages}
            }
          );

          my $pars = {};

          $pars -> {$formdata -> {$_} -> {assign} -> {name}} = plain($formdata -> {$_} -> {name})
            for (qw(
              posterBody
              uniqueID
              followUp
              quoteChar
              userID
              posterName
              posterEmail
              posterURL
              posterImage
              )
            );

          my $cgi = $param -> {cgi};

          my $tpar = {
            thread   => $param -> {thread},
            template => $param -> {tree},
            start    => $param -> {posting},
            cgi      => $cgi
          };

          my $parent_pars;

          $parent_pars = {
            $assign->{parentTitle} => plain(defined $pheader->{subject}  ? $pheader->{subject}  : ''),
            $assign->{parentCat}   => plain(defined $pheader->{category} ? $pheader->{category} : ''),
            $assign->{parentName}  => plain(defined $pheader->{name}     ? $pheader->{name}     : ''),
            $assign->{parentTime}  => plain(hr_time($pheader->{time})),
            $assign->{parentLink}  => query_string (
              { $cgi -> {thread} => $param -> {thread},
                $cgi -> {posting} => ($pnode -> getAttribute ('id') =~ /(\d+)/)[0]
              })
          } if (%$pheader);

          print ${$template -> scrap (
            $assign->{mainDoc},
            { $assign->{name}                            => plain(defined $header->{name}  ? $header->{name}  : ''),
              $assign->{email}                           => plain(defined $header->{email} ? $header->{email} : ''),
              $assign->{home}                            => plain(defined $header->{home}  ? $header->{home}  : ''),
              $assign->{image}                           => plain(defined $header->{image} ? $header->{image} : ''),
              $assign->{time}                            => plain(hr_time($header->{time})),
              $assign->{message}                         => $text,
              $assign->{messageTitle}                    => plain(defined $header->{subject}  ? $header->{subject}  : ''),
              $assign->{messageCat}                      => plain(defined $header->{category} ? $header->{category} : ''),
              $param->{tree}->{main}                     => html_thread ($msg, $template, $tpar),
              $formact->{post}->{assign}                 => $formact->{post}->{url},
              $formact->{vote}->{assign}                 => $formact->{vote}->{url},
              $formdata->{posterBody}->{assign}->{value} => $area,
              $formdata->{uniqueID}  ->{assign}->{value} => plain(unique_id),
              $formdata->{followUp}  ->{assign}->{value} => plain($param -> {thread}.';'.$param -> {posting}),
              $formdata->{quoteChar} ->{assign}->{value} => "&#255;".plain(defined $view -> {quoteChars} ? $view -> {quoteChars} : ''),
              $formdata->{userID}    ->{assign}->{value} => '',
              $assign->{firsttime}                       => $param->{firsttime} ? $param->{firsttime} : '',
              $assign->{voted}                           => $param->{voted} ? $param->{voted} : ''
            },
            $pars,
            $parent_pars
          )};

          # all output done
          #
          close STDOUT;

          if ($param->{firsttime}) {
            my $cache = new Posting::Cache ($param->{cachepath});
            $cache -> add_view (
              { thread  => $param -> {thread},
                posting => $param -> {posting}
              }
            );
          }
        }
      }
    }
  }

  return;
}

### message_as_HTML () #########################################################
#
# create HTML String for the Messagetext
#
# Params: $xml      - XML::DOM::Document object
#         $template - Template object
#         $param    - Hash reference
#                     (assign, posting, quoteChars, quoting)
#
# Return: HTML String
#
sub message_as_HTML ($$$) {
  my ($xml, $template, $param) = @_;

  my $assign = $param -> {assign};
  my $body = get_message_body ($xml, $param -> {posting});

  my $text = message_field (
    $body,
    { quoteChars => plain ($param -> {quoteChars}),
      quoting    => $param -> {quoting},
      startCite  => ${$template -> scrap ($assign -> {startCite})},
      endCite    => ${$template -> scrap ($assign -> {endCite})}
    }
  );

  # return
  $text;
}

# keep 'require' happy
1;

#
#
### end of Template::Posting ###################################################