package Template::Archive;

################################################################################
#                                                                              #
# File:        shared/Template/Archive.pm                                      #
#                                                                              #
# Authors:     Frank Schoenmann <fs@tower.de>, 2001-06-04                      #
#                                                                              #
# Description: archive display                                                 #
#                                                                              #
################################################################################

use strict;

use Lock qw(:READ);
use Encode::Posting;
use Encode::Plain; $Encode::Plain::utf8 = 1;
use Posting::_lib qw(
    get_message_node
    get_message_header
    get_message_body

    parse_single_thread
    parse_xml_file

    hr_time

    KILL_DELETED
);
use Template;
use Template::_conf;
use Template::_thread;

################################################################################
#
# Export
#
use base qw(Exporter);
@Template::Archive::EXPORT = qw(print_thread_as_HTML);


### print_year_as_HTML () ######################################################
#
# yearly overview over months
#
# Params:
#         $tempfile   template filename
#         $param      hash reference
# Return: -none-
#


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

    my $template = new Template $tempfile;


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

    my $tpar = {
        'thread'    => $param->{'thread'},
        'template'  => $param->{'tree'},
        'start'     => '-1',
        'cgi'       => $param->{'cgi'},
        'addParam'  => $addparam
    };

    my $tmplparam = {
            $assign->{'threadCategory'} => $thread->[0]->{'cat'},
            $assign->{'threadTitle'}    => $thread->[0]->{'subject'},
            $assign->{'threadYear'}     => $param->{'year'},
            $assign->{'threadMonth'}    => $param->{'month'},
            $param->{'tree'}->{'main'}  => html_thread($thread, $template, $tpar)
    };

    print ${$template->scrap(
        $assign->{'threadDocStart'},
        $tmplparam
    )};

    for (@$thread) {
        my $mnode = get_message_node($xml, 't'.$tid, 'm'.$_->{'mid'});
        my $header = get_message_header($mnode);
        my $body = get_message_body($xml, 'm'.$_->{'mid'});

        my $text = message_field (
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
            }
        )};
    }

    print ${$template->scrap(
        $assign->{'threadDocEnd'},
        $tmplparam
    )};
}


# keep require happy
1;

#
#
### end of Template::Archive ###################################################
