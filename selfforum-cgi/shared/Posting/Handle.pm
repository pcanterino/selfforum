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

@EXPORT = qw(hide_posting recover_posting modify_posting);

use Posting::_lib qw(get_message_node save_file);

use XML::DOM;

### hide_posting () ############################################################
#
# Hide a posting: set 'invisible' flag
#
# Params: $forum  Path and filename of forum
#         $tpath  Path to thread files
#         \%info  Hash reference: 'thread', 'posting', 'indexFile'
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
# Return: Status code
#
sub change_posting_visibility($$$$)
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

    return save_file($fname, \$xml->toString);
}

### modify_posting () ##########################################################
#
# Modify a posting (only subject and category until now!)
#
# Params: $forum  Path and filename of forum
#         $tpath  Path to thread files
#         \%info  Reference: 'thread', 'posting', 'indexFile', 'data'
#                 (\%hashref: 'subject', 'category', 'body')
# Return: -none-
#
sub modify_posting($$$)
{
    my ($forum, $tpath, $info) = @_;
    my ($tid, $mid, $indexFile, $data) = ('t' . $info->{'thread'},
                                          'm' . $info->{'posting'},
                                          $info->{'indexFile'},
                                          $info->{'data'});
    my ($subject, $category, $body) = ($data->{'subject'}, $data->{'category'}, $data->{'body'});

    my %msgdata;

    # These values may be changed by change_posting_value()
    $subject && $msgdata{'Subject'} = $subject;
    $category && $msgdata{'Category'} = $category;

    #
    my $tfile = $tpath . '/' . $tid . '.xml';
    change_posting_value($tfile, $tid, $mid, \$msgdata);
    change_posting_value($forum, $tid, $mid, \$msgdata);
}

### change_posting_value () ####################################################
#
# Change specific values of a posting
#
# Params: $fname    Filename
#         $tid      Thread ID
#         $mid      Message ID
#         \%values  New values
# Return: Status code
#
sub change_posting_value($$$$)
{
    my ($fname, $tid, $mid, $values) = @_;

    my $parser = new XML::DOM::Parser;
    my $xml = $parser->parsefile($fname);

    my $mnode = get_message_node($xml, $tid, $mid);

    for (keys %$values)
    {
        # Find first direct child node with name $_
        my $nodes = $mnode->getElementsByTagName($_, 0);
        my $node = $nodes->item(0);
        $node->setValue($values->{$_});
    }

    return save_file($fname, \$xml->toString);
}


1;