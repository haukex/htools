#!/usr/bin/env perl
use warnings;
use strict;
use Test::More tests => 9;

=head1 SYNOPSIS

Tests for F<htmlrescache>.

=head1 AUTHOR, COPYRIGHT, AND LICENSE

Copyright (c) 2018 Hauke Daempfling (haukex@zero-g.net)
at the Leibniz Institute of Freshwater Ecology and Inland Fisheries (IGB),
Berlin, Germany, L<http://www.igb-berlin.de/>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but B<WITHOUT ANY WARRANTY>; without even the implied warranty of
B<MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE>. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see L<http://www.gnu.org/licenses/>.

=cut

my $DEBUG = 0; # enable htmlrescache debug output

use FindBin;
use Path::Class qw/file dir/;

# locate target script and load IPC::Run3::Shell
my $TARGET;
BEGIN {
	$TARGET = dir($FindBin::Bin)->parent->file('htmlrescache');
	-f -x $TARGET or die "Could not find target script $TARGET";
	note "Am testing $TARGET";
}
use IPC::Run3::Shell
	{ show_cmd => Test::More->builder->output },
	'git',
	[ htmlrescache => $^X, $TARGET ];

# set up temp dir
my $TEMPDIR = Path::Class::tempdir(CLEANUP=>1);
note "Working in $TEMPDIR";
chdir $TEMPDIR or die "chdir $TEMPDIR: $!";
git 'init';

# set up test files
my $TESTHTML = <<'END_HTML';
<!--cacheable--><link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/normalize/8.0.0/normalize.min.css" integrity="sha256-oSrCnRYXvHG31SBifqP2PM1uje7SJUyX0nTwO2RJV54=" crossorigin="anonymous" />
<!--cacheable--><script src="https://code.jquery.com/jquery-3.3.1.min.js" integrity="sha256-FgpCb/KJQlLNfOu91ta32o/NMZxltwRo8QtmkMRdAu8=" crossorigin="anonymous"></script>
END_HTML
my $testfile1 = $TEMPDIR->file('test1.html');
$testfile1->spew("one\n".$TESTHTML);
$TEMPDIR->subdir('foo','bar')->mkpath;
my $testfile2 = $TEMPDIR->file('foo','bar','test2.html');
$testfile2->spew("two\n".$TESTHTML);
my $cachedir = $TEMPDIR->subdir('_cache');

# first run of htmlrescache
htmlrescache +($DEBUG?'-dD':'-q'), 'init';

# check results of init command
my $gitconf = git 'config', '--local', '--get-regexp', '^filter\\.';
note $gitconf = join "\n", sort split(/\n/, $gitconf);
my $debugopt = $DEBUG ? ' -d' : '';
is $gitconf,
  "filter.htmlrescache.clean $^X $TARGET -c$cachedir$debugopt clean %f\n"
 ."filter.htmlrescache.smudge $^X $TARGET -c$cachedir$debugopt smudge %f",
 "git config looks ok";
my $gitattrfile = $TEMPDIR->file('.gitattributes');
is $gitattrfile->slurp,
	"*.html\tfilter=htmlrescache\n", '.gitattributes created ok';

# commit and re-checkout files
git 'add', $gitattrfile, $testfile1, $testfile2;
git 'commit', '-qm', 'foo';
$testfile1->remove;
$testfile2->remove;
git 'checkout', '-f', $testfile1, $testfile2;

# check smudged files
is $testfile1->slurp, <<'END_HTML', "smudged $testfile1";
one
<!-- CACHED FROM "https://cdnjs.cloudflare.com/ajax/libs/normalize/8.0.0/normalize.min.css" --><link rel="stylesheet" href="_cache/normalize.min.css" integrity="sha256-oSrCnRYXvHG31SBifqP2PM1uje7SJUyX0nTwO2RJV54=" crossorigin="anonymous" />
<!-- CACHED FROM "https://code.jquery.com/jquery-3.3.1.min.js" --><script src="_cache/jquery-3.3.1.min.js" integrity="sha256-FgpCb/KJQlLNfOu91ta32o/NMZxltwRo8QtmkMRdAu8=" crossorigin="anonymous"></script>
END_HTML
is $testfile2->slurp, <<'END_HTML', "smudged $testfile2";
two
<!-- CACHED FROM "https://cdnjs.cloudflare.com/ajax/libs/normalize/8.0.0/normalize.min.css" --><link rel="stylesheet" href="../../_cache/normalize.min.css" integrity="sha256-oSrCnRYXvHG31SBifqP2PM1uje7SJUyX0nTwO2RJV54=" crossorigin="anonymous" />
<!-- CACHED FROM "https://code.jquery.com/jquery-3.3.1.min.js" --><script src="../../_cache/jquery-3.3.1.min.js" integrity="sha256-FgpCb/KJQlLNfOu91ta32o/NMZxltwRo8QtmkMRdAu8=" crossorigin="anonymous"></script>
END_HTML

# modify files (so clean will have something to do)
{ print {$testfile1->opena} "111\n"; }
{ print {$testfile2->opena} "222\n"; }
git 'commit', '-aqm', 'bar';

# check clean files
sub getblob {
	my ($fn) = @_;
	my $l = git 'ls-tree', '-z', 'HEAD', '--', $fn;
	note $l;
	my ($blobsha) = $l =~ /\A\S+\ \S+\ ([0-9A-Fa-f]+)\t.+\0\z/ or die $l;
	return scalar git 'cat-file', '-p', $blobsha;
}
is getblob($testfile1), "one\n${TESTHTML}111\n", "clean $testfile1";
is getblob($testfile2), "two\n${TESTHTML}222\n", "clean $testfile2";

# check cached files
use Digest;
sub sri {
	my ($fn) = @_;
	open my $fh, '<:raw', $fn or die "$fn: $!";
	my $dig = Digest->new("SHA-256")->addfile($fh)->b64digest;
	length($dig)%2 and $dig.='=';
	return "sha256-$dig";
}
is sri($cachedir->file('normalize.min.css')), 'sha256-oSrCnRYXvHG31SBifqP2PM1uje7SJUyX0nTwO2RJV54=', 'normalize.min.cs is present';
is sri($cachedir->file('jquery-3.3.1.min.js')), 'sha256-FgpCb/KJQlLNfOu91ta32o/NMZxltwRo8QtmkMRdAu8=', 'jquery-3.3.1.min.js is present';
is $cachedir->file('.index')->slurp, <<'END_INDEXF', 'index file looks good';
jquery-3.3.1.min.js	https://code.jquery.com/jquery-3.3.1.min.js
normalize.min.css	https://cdnjs.cloudflare.com/ajax/libs/normalize/8.0.0/normalize.min.css
END_INDEXF

#TODO Later: Tests for a different cache directory - possibly even outside git WD?

done_testing;
