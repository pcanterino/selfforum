package Posting::Handle;

################################################################################
#                                                                              #
# File:        shared/Posting/Handle.pm                                        #
#                                                                              #
# Authors:     Frank Schoenmann <fs@tower.de>, 2001-02-27                      #
#                                                                              #
# Description: Allow modifications of postings                                 #
#                                                                              #
################################################################################

use strict;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(hide_posting recover_posting);

use Posting::_lib qw(get_message_node);

use XML::DOM;

### hide_posting () ############################################################
#
# Hide a posting: set 'invisible' flag
#
# Params: $forum     Path and filename of forum
#         $tpath     Path to thread files
#         \%hashref  Reference: 'thread', 'posting', 'indexFile'
# Return: -none-
#
sub hide_posting($$$)
{
    my ($forum, $tpath, $info) = @_;
    my ($tid, $mid, $indexFile) = ('t' . $info->{'thread'},
                                   'm' . $info->{'posting'},
                                   $info->{'indexFile'});

    my $tfile = $tpath . '/' . $tid . '.xml';
    change_posting_visibility($tfile, $tid, $mid, 1);
    change_posting_visibility($forum, $tid, $mid, 1);
}

### recover_posting() ##########################################################
#
# Recover a posting: delete 'invisible' flag
#
# Params: $forum     Path and filename of forum
#         $tpath     Path to thread files
#         \%hashref  Reference: 'thread', 'posting', 'indexFile'
# Return: -none-
#
sub recover_posting($$$)
{
    my ($forum, $tpath, $info) = @_;
    my ($tid, $mid, $indexFile) = ('t' . $info->{'thread'},
                                   'm' . $info->{'posting'},
                                   $info->{'indexFile'});

    my $tfile = $tpath . '/' . $tid . '.xml';
    change_posting_visibility($tfile, $tid, $mid, 0);
    change_posting_visibility($forum, $tid, $mid, 0);
}

### change_posting_visibility () ###############################################
#
# Set a postings visibility flag to $invisible
#
# Params: $fname      Filename
#         $tid        Thread ID
#         $mid        Message ID
#         $invisible  1 - invisible, 0 - visible
# Return: -none-
#
sub change_posting_visibility($$$)
{
    my ($fname, $tid, $mid, $invisible) = @_;

    my $parser = new XML::DOM::Parser;
    my $xml = $parser->parsefile($fname);

    # Set flag in given msg
    my $mnode = get_message_node($xml, $tid, $mid);
    $mnode->setAttribute('invisible', $invisible);

    # Set flag in sub nodes
    for ($mnode->getElementsByTagName('Message'))
    {
        $_->setAttribute('invisible', $invisible);
    }

    $xml->printToFile($fname.'.temp');
    rename $fname.'.temp', $fname;
}


1;
