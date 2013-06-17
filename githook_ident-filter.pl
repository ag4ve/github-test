#!/usr/bin/env perl 
#===============================================================================
#
#         FILE:  githook_ident_filter.pl
#
#        USAGE:  ./githook_ident_filter.pl  
#
#  DESCRIPTION:  Insert or change version info for lines where $Id$ in near 
#                the beginning such as:
#                # $Id: <filename> v0.1 <hash> YYYY/MM/DD HH:MM:SS <user>: <commit> $
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Shawn Wilson <swilson@korelogic.com>
#      COMPANY:  Korelogic
#      VERSION:  1.0
#      CREATED:  06/17/13 10:04:58
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

my $full_path = shift;

my $in;
$full_path =~ /.*\/(.*)/;
$in->{file} = $1 // $full_path;

$in->{date}   = `git log --pretty=format:"%ad" -1 -- $full_path`;
$in->{hash}   = `git log --pretty=format:"%h" -1 -- $full_path`;
$in->{commit} = `git log --pretty=format:"%s" -1 -- $full_path`;
$in->{author} = `git log --pretty=format:"%an" -1 -- $full_path`;
$in->{signed} = `git log --pretty=format:"%G?" -1 -- $full_path`;
$in->{signer} = `git log --pretty=format:"%GS" -1 -- $full_path`;


while(<STDIN>)
{
  my $line = $_;

  unless ($line =~ /.{0,4}\$Id(:| ?\$).*/)
  {
    print $line;
    next;
  }

  my $def;
  # Disect Id line
  $line = s/([^\$]{0,4}\$Id:) ?//;
  $in->{id} = $1;
  $line = s/([-a-zA-Z0-9_\.]+),? ?//;
  $def->{file} = $1;
  $line = s/v ?([0-9\.]+) //; 
  $def->{version} = $1;
  $line = s/([0-9a-f]{7,40}) //;
  $def->{hash} = $1;
  $line = s/((?:(?:[A-Za-z]{3} ){1,2})?[-0-9\/: ]+) //;
  $def->{date} = $1;
  $line = s/([^:\$]+:) ?//;
  $def->{author} = $1;
  $line = s/([^\$]+) ?$//;
  $def->{commit} = $1;

  if (defined($def->{version}) and $def->{version} =~ /[0-9\.]+/)
  {
    my @vals = split(/\./, $def->{version});
    $vals[-1] = $vals[-1] + 1;
    $in->{version} = 'v' . join('.', @vals);
  }

  # Put back together
  my $output;
  $output = format_line($in, $def);

  if (!defined($output) or (defined($output) and length($output) <= 1))
  {
    $output = format_line($in, $in);
  }

  print $output . "\$\n";
}

sub format_line
{
  my ($in, $def) = @_;

  my $ret;

  foreach my $part (qw/id file version hash date author commit/)
  {
    if (defined $def->{$part} and $in->{$part})
    {
      if ($part eq 'author' and defined($in->{signed}) and $in->{signed} eq 'G' and defined($in->{signer}))
      {
        $ret .= $in->{signer} . ' ';
      }
      else
      {
        $ret .= $in->{$part} . ' ';
      }
    }
  }

  return $ret;
}

