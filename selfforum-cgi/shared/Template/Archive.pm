package Template::Archive;

################################################################################
#                                                                              #
# File:        shared/Template/Archive.pm                                      #
#                                                                              #
# Authors:     Andre Malo       <nd@o3media.de>, 2001-06-16                    #
#              Frank Schoenmann <fs@tower.de>,   2001-06-08                    #
#                                                                              #
# Description: archive display                                                 #
#                                                                              #
################################################################################

use strict;
use vars qw(
  @EXPORT
  $VERSION
);

use Lock qw(:READ);
use Encode::Posting;
use Encode::Plain; $Encode::Plain::utf8 = 1;
use Posting::_lib qw(
    get_message_node
    get_message_header
    get_message_body

    get_all_threads
    parse_single_thread
    parse_xml_file

    very_short_hr_time
    short_hr_time
    hr_time
    month

    KILL_DELETED
);
use Template;
use Template::_conf;
use Template::_thread;

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
    print_overview_as_HTML
    print_year_as_HTML
    print_month_as_HTML
    print_thread_as_HTML
);


### print_overview_as_HTML () ##################################################
#
# archive entry
#
# Params: $arcdir     main archive directory
#         $tempfile   template filename
#         $param      hash reference
# Return: -none-
#
sub print_overview_as_HTML($$$) {
    my ($arcdir, $tempfile, $param) = @_;

    my $assign = $param->{'assign'};

    my $template = new Template $tempfile;

    #
    # archiveDocStart
    #
    print ${$template->scrap(
        $assign->{'archiveDocStart'}
    )};

    #
    # globbing to find year directories
    #
    for (<$arcdir????>) {
        s/$arcdir//;
        print ${$template->scrap(
            $assign->{'archiveDocEntry'},
            {
                $assign->{'year'}   => $_
            }

        )};
    }

#   for (my $month = 1; $month <= 12; $month++) {
#       if (-e $yeardir.$month.'/') {
#           print ${$template->scrap(
#               $assign->{'yearDocEntry'},
#               {
#                   $assign->{'year'}       => $param->{'year'},
#                   $assign->{'month'}      => $month,
#                   $assign->{'monthName'}  => month($month)
#               }
#           )};
#       }
#   }

    #
    # archiveDocEnd
    #
    print ${$template->scrap(
        $assign->{'archiveDocEnd'}
    )};
}

### print_year_as_HTML () ######################################################
#
# yearly overview over months
#
# Params: $yeardir    directory, which contains month directories
#         $tempfile   template filename
#         $param      hash reference
# Return: -none-
#
sub print_year_as_HTML($$$) {
    my ($yeardir, $tempfile, $param) = @_;

    my $assign = $param->{'assign'};

    my $template = new Template $tempfile;

    #
    # check if this year's archive exist
    #
    unless (-e $yeardir) {
        print ${$template->scrap(
            $assign->{'error'},
            {
                $assign->{'errorText'}  => "Es existieren keine Nachrichten für dieses Jahr."
            }
        )};
    }

    my $tmplparam = {
            $assign->{'year'}           => $param->{'year'},
    };

    #
    # yearDocStart
    #
    print ${$template->scrap(
        $assign->{'yearDocStart'},
        $tmplparam
    )};

    for (my $month = 1; $month <= 12; $month++) {
        if (-e $yeardir.$month.'/') {
            print ${$template->scrap(
                $assign->{'yearDocEntry'},
                {
                    $assign->{'year'}       => $param->{'year'},
                    $assign->{'month'}      => $month,
                    $assign->{'monthName'}  => month($month)
                }
            )};
        }
    }

    #
    # yearDocEnd
    #
    print ${$template->scrap(
        $assign->{'yearDocEnd'},
        $tmplparam
    )};
}

### print_month_as_HTML () #####################################################
#
# monthly overview over threads
#
# Params: $mainfile   XML file on a per-month base
#         $tempfile   template filename
#         $param      hash reference
# Return: -none-
#
sub print_month_as_HTML($$$) {
    my ($mainfile, $tempfile, $param) = @_;

    my $assign = $param->{'assign'};

    my $template = new Template $tempfile;

    #
    # check if XML file exists
    #
    unless (-e $mainfile) {
        print ${$template->scrap(
            $assign->{'error'},
            {
                $assign->{'errorText'}  => "Es existieren keine Nachrichten für diesen Monat."
            }
        )};
        return;
    }

    #
    # try locking and read/parse threads
    #
    my ($threads, $locked);
    unless ($locked = lock_file($mainfile) and $threads = get_all_threads($mainfile, KILL_DELETED)) {
        print ${$template->scrap(
            $assign->{'error'},
            {
                $assign->{'errorText'}  => "Fehler beim Locking."
            }
        )};
        return;
    }
    unlock_file($mainfile);

    my $tmplparam = {
            $assign->{'year'}           => $param->{'year'},
            $assign->{'month'}          => $param->{'month'},
            $assign->{'monthName'}      => month($param->{'month'})
    };

    #
    # monthDocStart
    #
    print ${$template->scrap(
        $assign->{'monthDocStart'},
        $tmplparam
    )};

    #
    # thread overview
    #
    for (sort keys %$threads) {
        print ${$template->scrap(
            $assign->{'monthThreadEntry'},
            {
                $assign->{'threadID'}       => $_,
                $assign->{'threadCategory'} => $threads->{$_}->[0]->{'cat'},
                $assign->{'threadTitle'}    => $threads->{$_}->[0]->{'subject'},
                $assign->{'threadTime'}     => short_hr_time($threads->{$_}->[0]->{'time'}),
                $assign->{'threadDate'}     => very_short_hr_time($threads->{$_}->[0]->{'time'}),
                $assign->{'year'}           => $param->{'year'},
                $assign->{'month'}          => $param->{'month'}
            }
        )};
    }

    #
    # monthDocEnd
    #
    print ${$template->scrap(
        $assign->{'monthDocEnd'},
        $tmplparam
    )};
}

### print_thread_as_HTML () ####################################################
#
# print a complete thread
#
# Params: $mainfile   thread XML file
#         $tempfile   template filename
#         $param      hash reference
# Return: -none-
#
sub print_thread_as_HTML($$$) {
    my ($mainfile, $tempfile, $param) = @_;

    my $assign = $param->{'assign'};
    my $tree = $param->{'tree'};
    my $tid = $param->{'thread'};

    my $template = new Template $tempfile;

    #
    # check if XML file exists
    #
    unless (-e $mainfile) {
        print ${$template->scrap(
            $assign->{'error'},
            {
                $assign->{'errorText'}  => "Der gewünschte Thread existiert nicht."
            }
        )};
        return;
    }

    my $view = get_view_params ({
        'adminDefault'  => $param->{'adminDefault'}
    });
    my $xml = parse_xml_file($mainfile);
    my $tnode = $xml->getElementsByTagName('Thread', 1)->item(0);
    my $thread = parse_single_thread($tnode, KILL_DELETED);

    my $addparam = {
        $tree->{'year'}   => $param->{'year'},
        $tree->{'month'}  => $param->{'month'}
    };

    #
    # used to print the thread view
    #
    my $tpar = {
        'thread'    => $param->{'thread'},
        'template'  => $param->{'tree'},
        'start'     => '-1',
        'cgi'       => $param->{'cgi'},
        'addParam'  => $addparam
    };

    #
    # threadDocStart
    #
    my $tmplparam = {
            $assign->{'threadCategory'} => $thread->[0]->{'cat'},
            $assign->{'threadTitle'}    => $thread->[0]->{'subject'},
            $assign->{'year'}           => $param->{'year'},
            $assign->{'month'}          => $param->{'month'},
            $assign->{'monthName'}      => month($param->{'month'}),
            $param->{'tree'}->{'main'}  => html_thread($thread, $template, $tpar)
    };

    print ${$template->scrap(
        $assign->{'threadDocStart'},
        $tmplparam,
        1
    )};

    #
    # print thread msgs
    #
    for (@$thread) {
        my $mnode = get_message_node($xml, 't'.$tid, 'm'.$_->{'mid'});
        my $header = get_message_header($mnode);
        my $body = get_message_body($xml, 'm'.$_->{'mid'});

        my $text = message_field(
            $body,
            {
                'quoteChars'    => plain($view->{'quoteChars'}),
                'quoting'       => $view->{'quoting'},
                'startCite'     => ${$template->scrap($assign->{'startCite'})},
                'endCite'       => ${$template->scrap($assign->{'endCite'})}
            }
        );


        print ${$template->scrap(
            $assign->{'posting'},
            {
                $assign->{'msgID'}          => $_->{'mid'},
                $assign->{'msgAuthor'}      => $_->{'name'},
                $assign->{'msgMail'}        => $header->{'email'},
                $assign->{'msgHomepage'}    => $header->{'home'},
                $assign->{'msgTime'}        => hr_time($header->{'time'}),
                $assign->{'msgCategory'}    => plain($header->{'category'}),
                $assign->{'msgSubject'}     => plain($header->{'subject'}),
                $assign->{'msgBody'}        => $text
            },
            1
        )};
    }

    #
    # threadDocEnd
    #
    print ${$template->scrap(
        $assign->{'threadDocEnd'},
        $tmplparam,
        1
    )};
}


# keep 'require' happy
1;

#
#
### end of Template::Archive ###################################################