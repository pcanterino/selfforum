package Handle;
#package Posting::Handle;

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

@EXPORT = qw(hide_posting);

#use Posting::_lib;

use XML::DOM;

### hide_posting () ############################################################
#
# Hide a posting: set 'invisible' flag
#
# Params: $forum     Path and filename of forum
#         $tpath     Path to thread files
#         \%hashref  Reference: 'thread', 'posting', 'indexFile'
# Return: Boolean
#
sub hide_posting($$$)
{
    my ($forum, $tpath, $info) = shift;
    my ($tid, $pid, $indexFile) = ('t' . $info->{'thread'},
                                   'm' . $info->{'posting'},
                                   $info->{'indexFile'});

    {
        # Change flag in thread xml file
        my $tfile = $tpath . '/' . $tid;

        my $parser = new XML::DOM::Parser;
        my $xml = $parser->parsefile($tfile);

        my $msgs = $xml->getElementsByTagName('Message');

        for (my $i = 0; $i < $msgs->getLength; $i++)
        {
            my $msg = $msgs->item($i);

            if ($msg->getAttribute('id')->getValue == $pid)
            {
                $msg->setAttribute('invisible', '1');
                last;
            }
        }

        # Save thread xml file
        $xml->printToFile($tfile . '.temp');
        rename $tfile . '.temp', $tfile;
    }

    {
        # Change flag in forum xml file
        my $parser = new XML::DOM::Parser;
        my $xml = $parser->parseFile($forum);

        my $msgs = $xml->getElementsByTagName('Message');

        for (my $i = 0; $i < $msgs->getLength; $i++)
        {
            my $msg = $msgs->item($i);

            if ($msg->getAttribute('id')->getValue == $pid)
            {
                $msg->setAttribute('invisible', '1');
                last;
            }
        }

        # Save forum xml file
        $xml->printToFile($forum . '.temp');
        rename $forum . '.temp', $forum;
    }
}




1;
