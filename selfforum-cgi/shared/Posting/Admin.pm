package Posting::Admin;

################################################################################
#                                                                              #
# File:        shared/Posting/Admin.pm                                         #
#              (was: ~Handle.pm)                                               #
#                                                                              #
# Authors:     Frank Schoenmann <fs@tower.de>, 2001-03-13                      #
#              Andre Malo       <nd@o3media.de>, 2001-03-29                    #
#                                                                              #
# Description: Allow administration of postings                                #
#                                                                              #
# Todo:        * Lock files before modification                                #
#              * Change body in change_posting_body()                          #
#              * Recursively set invisibility flag in main forum xml by        #
#                hide_posting() and recover_posting()                          #
#                                                                              #
################################################################################

use strict;

use base qw(Exporter);

@Posting::Admin::EXPORT = qw(hide_posting recover_posting modify_posting add_user_vote level_vote);

use Lock qw(:READ);
use Posting::_lib qw(get_message_node save_file get_all_threads
                     create_forum_xml_string);

use XML::DOM;

### add_user_vote () ###########################################################
#
# Increase number of user votes (only in thread file)
#
# Params: $forum  Path and filename of forum
#         $tpath  Path to thread files
#         \%info  Hash reference: 'thread', 'posting', 'percent'
# Return: Status code (Bool)
#
# Todo:
#  * Lock files before modification
#
sub add_user_vote()
{
    my ($forum, $tpath, $info) = @_;
    my ($tid, $mid, $percent) = ($info->{'thread'},
                                 $info->{'posting'},
                                 $info->{'percent'});

    # Thread
    my $tfile = $tpath . '/t' . $tid . '.xml';

    my $parser = new XML::DOM::Parser;
    my $xml = $parser->parsefile($tfile);

    my $mnode = get_message_node($xml, $tid, $mid);
    my $votes = $mnode->getAttribute('votingUser') + 1;
    $mnode->setAttribute('votingUser', $votes);

    return save_file($tfile, \$xml->toString);
}

### level_vote () ##############################################################
#
# Set 1st or 2nd level voting (only in thread file)
#
# Params: $forum  Path and filename of forum
#         $tpath  Path to thread files
#         \%info  Hash reference: 'thread', 'posting', 'level', 'value'
# Return: Status code (Bool)
#
# Todo:
#  * Lock files before modification
#
sub level_vote
{
    my ($forum, $tpath, $info´) = @_;
    my ($tid, $mid, $level, $value) = ($info->{'thread'},
                                       $info->{'posting'},
                                       $info->{'level'},
                                       $info->{'value'});

    # Thread
    my $tfile = $tpath . '/t' . $tid . '.xml';

    my $parser = new XML::DOM::Parser;
    my $xml = $parser->parsefile($tfile);

    my $mnode = get_message_node($xml, $tid, $mid);

    if ($value == undef)
    {
        removeAttribute($level);
    }
    else
    {
        $mnode->setAttribute($level, $value);
    }

    return save_file($tfile, \$xml->toString);
}

### hide_posting () ############################################################
#
# Hide a posting: set 'invisible' flag
#
# Params: $forum  Path and filename of forum
#         $tpath  Path to thread files
#         \%info  Hash reference: 'thread', 'posting', 'indexFile'
# Return: -none-
#
# Todo:
#  * set flags recursively in forum xml
#  * lock files before modification
#
sub hide_posting($$$)
{
    my ($forum, $tpath, $info) = @_;
    my ($tid, $mid, $indexFile) = ($info->{'thread'},
                                   $info->{'posting'},
                                   $info->{'indexFile'});

    # Thread
    my $tfile = $tpath . '/t' . $tid . '.xml';
    change_posting_visibility($tfile, 't'.$tid, 'm'.$mid, 1);

    # Forum
    my ($f, $lthread, $lmsg, $dtd, $zlev) = get_all_threads($forum, 0, 0);  # filter deleted, descending

    for (@{$f->{$tid}})
    {
        if ($_->{'mid'} == $mid)
        {
            $_->{'deleted'} = 1;
        }
    }

    my %cfxs = (
        'dtd'         => $dtd,
        'lastMessage' => $lmsg,
        'lastThread'  => $lthread
    );
    my $xmlstring = create_forum_xml_string($f, \%cfxs);
    save_file($forum, $$xmlstring);
}

### recover_posting() ##########################################################
#
# Recover a posting: delete 'invisible' flag
#
# Params: $forum  Path and filename of forum
#         $tpath  Path to thread files
#         \%info  Hash reference: 'thread', 'posting', 'indexFile'
# Return: -none-
#
# Todo:
#  * set flags recursive in forum xml
#  * lock files before modification
#
sub recover_posting($$$)
{
    my ($forum, $tpath, $info) = @_;
    my ($tid, $mid, $indexFile) = ($info->{'thread'},
                                   $info->{'posting'},
                                   $info->{'indexFile'});

    # Thread
    my $tfile = $tpath . '/t' . $tid . '.xml';
    change_posting_visibility($tfile, 't'.$tid, 'm'.$mid, 0);

    # Forum
    my ($f, $lthread, $lmsg, $dtd, $zlev) = get_all_threads($forum, 1, 0);  # do not filter deleted, descending

    for (@{$f->{$tid}})
    {
        if ($_->{'mid'} == $mid)
        {
            $_->{'deleted'} = 0;
        }
    }

    my %cfxs = (
        'dtd'         => $dtd,
        'lastMessage' => $lmsg,
        'lastThread'  => $lthread
    );
    my $xmlstring = create_forum_xml_string($f, \%cfxs);
    save_file($forum, $$xmlstring);
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
#                 (data = \%hashref: 'subject', 'category', 'body')
# Return: -none-
#
sub modify_posting($$$)
{
    my ($forum, $tpath, $info) = @_;
    my ($tid, $mid, $indexFile, $data) = ($info->{'thread'},
                                          $info->{'posting'},
                                          $info->{'indexFile'},
                                          $info->{'data'});
    my ($subject, $category, $body) = ($data->{'subject'}, $data->{'category'}, $data->{'body'});

    my %msgdata;

    # These values may be changed by change_posting_value()
    $subject && $msgdata{'Subject'} = $subject;
    $category && $msgdata{'Category'} = $category;

    # Thread
    my $tfile = $tpath . '/t' . $tid . '.xml';
    change_posting_value($tfile, 't'.$tid, 'm'.$mid, \$msgdata);
    $body && change_posting_body($tfile, 't'.$tid, 'm'.$mid, $body);

    # Forum (does not contain msg bodies)
    if ($subject or $category)
    {
        my ($f, $lthread, $lmsg, $dtd, $zlev) = get_all_threads($forum, 1, 0);

        for (@{$f->{$tid}})
        {
            if ($_->{'mid'} == $mid)
            {
                $subject && $_->{'subject'} = $subject;
                $category && $_->{'cat'} = $category;
            }
        }

        my %cfxs = (
            'dtd'         => $dtd,
            'lastMessage' => $lmsg,
            'lastThread'  => $lthread
        );
        my $xmlstring = create_forum_xml_string($f, \%cfxs);
        save_file($forum, $$xmlstring);
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

### change_posting_body () #####################################################
#
# Change body of a posting
#
# Params: $fname  Filename
#         $tid    Thread ID (unused, for compatibility purposes)
#         $mid    Message ID
#         $body   New body
# Return: Status code
#
# Todo:
#  * Change body
#
sub change_posting_body($$$$)
{
    my ($fname, $tid, $mid, $body) = @_;

    my $parser = new XML::DOM::Parser;
    my $xml = $parser->parsefile($fname);

    my $mbnody = get_message_body($xml, $mid);

    # todo: change body

    return save_file($fname, \$xml->toString);
}


# Let it be true
1;