#!/usr/bin/env perl
use warnings;
use strict;
use Test::More;

=head1 SYNOPSIS

Tests for F<smartunpack>.

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

my $VERBOSE = 0;

use Path::Class ();
use FindBin;
use IPC::Run3::Shell qw/:FATAL :run/;

use Archive::Zip qw/AZ_OK/;
use Archive::Tar; # handles gzip and bzip2

my $uut = Path::Class::Dir->new($FindBin::Bin)->parent
	->file('smartunpack')->stringify;

my $tempdir = Path::Class::tempdir(TMPDIR=>1,
	TEMPLATE=>'smartunpack_tests_XXXXXXXXXX',CLEANUP=>1);

sub dotest {
	my ($arcf,$exp,$args) = @_;
	$args ||= [];
	@$exp = sort @$exp;
	my $targ;
	#TODO Later: The following doesn't check STDOUT
	if (grep {$_ eq '--recursive' || $_ eq '-r'} @$args) { # meh
		$targ = $arcf;
		run $^X, $uut, $VERBOSE?'-v':'-q', @$args, $arcf, {fail_on_stderr=>1};
	}
	else {
		$targ = Path::Class::tempdir(DIR=>$tempdir,
			TEMPLATE=>'su_test_target_XXXXXXXXXX',CLEANUP=>1);
		run $^X, $uut, $VERBOSE?'-v':'-q', @$args, $arcf, $targ, {fail_on_stderr=>1};
	}
	my @got;
	$targ->recurse( callback => sub {
			my $found = shift;
			return if $found eq $targ;
			my $name = $found->relative($targ)->stringify;
			$name .= '/' if $found->is_dir; #TODO Later: this will all only work on *NIX for now
			push @got, $name;
		} );
	@got = sort @got;
	is_deeply \@got, $exp, $arcf->basename or diag explain \@got;
}

{
	my $f = $tempdir->file('justplainfiles.zip');
	my $zip = Archive::Zip->new();
	$zip->addString('Foo!', 'foo.txt');
	$zip->addString('Bar!', 'bar.txt');
	$zip->addString('Quz!', 'quz.txt');
	$zip->writeToFileNamed("$f")==AZ_OK or die "zip error";
	my @exp = qw{ justplainfiles/ justplainfiles/foo.txt justplainfiles/bar.txt
		justplainfiles/quz.txt };
	dotest($f,\@exp);
}

{
	my $f = $tempdir->file('oneplainfile.zip');
	my $zip = Archive::Zip->new();
	$zip->addString('Foobar!', 'foo.txt');
	$zip->writeToFileNamed("$f")==AZ_OK or die "zip error";
	my @exp = qw{ oneplainfile/ oneplainfile/foo.txt };
	dotest($f,\@exp);
}

{
	my $f = $tempdir->file('onedirsamename.zip');
	my $zip = Archive::Zip->new();
	$zip->addString('Foo!', 'onedirsamename/foo.txt');
	$zip->addString('Bar!', 'onedirsamename/bar.txt');
	$zip->addString('Quz!', 'onedirsamename/quz.txt');
	$zip->writeToFileNamed("$f")==AZ_OK or die "zip error";
	my @exp = qw{ onedirsamename/ onedirsamename/foo.txt onedirsamename/bar.txt
		onedirsamename/quz.txt };
	dotest($f,\@exp);
}

{
	my $f = $tempdir->file('onedirlongername.zip');
	my $zip = Archive::Zip->new();
	$zip->addString('Foo!', 'onedirlongername-blah/foo.txt');
	$zip->addString('Bar!', 'onedirlongername-blah/bar.txt');
	$zip->addString('Quz!', 'onedirlongername-blah/quz.txt');
	$zip->writeToFileNamed("$f")==AZ_OK or die "zip error";
	my @exp = qw{ onedirlongername-blah/ onedirlongername-blah/foo.txt
		onedirlongername-blah/bar.txt onedirlongername-blah/quz.txt };
	dotest($f,\@exp);
}

{
	my $f = $tempdir->file('onedirshortername-blah.zip');
	my $zip = Archive::Zip->new();
	$zip->addString('Foo!', 'onedirshortername/foo.txt');
	$zip->addString('Bar!', 'onedirshortername/bar.txt');
	$zip->addString('Quz!', 'onedirshortername/quz.txt');
	$zip->writeToFileNamed("$f")==AZ_OK or die "zip error";
	my @exp = qw{ onedirshortername-blah/ onedirshortername-blah/foo.txt
		onedirshortername-blah/bar.txt onedirshortername-blah/quz.txt };
	dotest($f,\@exp);
}

{
	my $f = $tempdir->file('onedirdifferentname.zip');
	my $zip = Archive::Zip->new();
	$zip->addString('Foo!', 'hellooneworld/foo.txt');
	$zip->addString('Bar!', 'hellooneworld/bar.txt');
	$zip->addString('Quz!', 'hellooneworld/quz.txt');
	$zip->writeToFileNamed("$f")==AZ_OK or die "zip error";
	my @exp = qw{ onedirdifferentname/ onedirdifferentname/foo.txt
		onedirdifferentname/bar.txt onedirdifferentname/quz.txt };
	dotest($f,\@exp);
}

{
	my $f = $tempdir->file('testtgz.tar.gz');
	my $tar = Archive::Tar->new();
	$tar->add_data('foo.txt', 'Foo!');
	$tar->add_data('bar.txt', 'Bar!');
	$tar->add_data('quz.txt', 'Quz!');
	$tar->write("$f", COMPRESS_GZIP, 'testtgz') or die "tar error: ".$tar->error;
	my @exp = qw{ testtgz/ testtgz/foo.txt testtgz/bar.txt testtgz/quz.txt };
	dotest($f,\@exp);
}

{
	my $f = $tempdir->file('testtbz2.tar.bz2');
	my $tar = Archive::Tar->new();
	$tar->add_data('foo.txt', 'Foo!');
	$tar->add_data('bar.txt', 'Bar!');
	$tar->add_data('quz.txt', 'Quz!');
	$tar->write("$f", COMPRESS_BZIP, 'testtbz2') or die "tar error: ".$tar->error;
	my @exp = qw{ testtbz2/ testtbz2/foo.txt testtbz2/bar.txt testtbz2/quz.txt };
	dotest($f,\@exp);
}

{
	my $f = $tempdir->file('test7z.7z');
	
	my $tmpwork = Path::Class::tempdir(CLEANUP=>1);
	my $thedir = $tmpwork->subdir('test7z');
	$thedir->mkpath(0);
	$thedir->file('foo.txt')->spew('Foo!');
	$thedir->file('bar.txt')->spew('Bar!');
	$thedir->file('quz.txt')->spew('Quz!');
	chdir($tmpwork) or die "chdir $tmpwork: $!";
	my $dummy = run '7z', 'a', $f, 'test7z', {fail_on_stderr=>1};
	
	my @exp = qw{ test7z/ test7z/foo.txt test7z/bar.txt test7z/quz.txt };
	dotest($f,\@exp);
}

{
	my $recur = Path::Class::tempdir(DIR=>$tempdir,
		TEMPLATE=>'recurse_test_XXXXXXXXXX',CLEANUP=>1);
	$recur->file('one.txt')->spew('111');
	$recur->subdir('two')->mkpath(0);
	$recur->subdir('two')->file('three.txt')->spew('222');
	
	my $inner = $tempdir->file('recur_inner.zip');
	my $zip = Archive::Zip->new();
	$zip->addString('111111', 'eleven.txt');
	$zip->addString('121212', 'twelve.txt');
	$zip->writeToFileNamed("$inner")==AZ_OK or die "zip error";
	
	my $f1 = $recur->file('four.zip');
	my $zip1 = Archive::Zip->new();
	$zip1->addString('555', 'five.txt');
	$zip1->addString('666', 'four/six.txt');
	$zip1->addString('777', 'four/seven.txt');
	$zip1->writeToFileNamed("$f1")==AZ_OK or die "zip error";
	
	my $f2 = $recur->subdir('two')->file('eight.zip');
	my $zip2 = Archive::Zip->new();
	$zip2->addString('999', 'eight/nine.txt');
	$zip2->addFile("$inner", 'eight/ten.zip');
	$zip2->writeToFileNamed("$f2")==AZ_OK or die "zip error";
	
	my @exp = qw{ one.txt two/ two/three.txt four.zip four/ four/five.txt
		four/four/ four/four/six.txt four/four/seven.txt two/eight.zip
		two/eight/ two/eight/nine.txt two/eight/ten.zip two/eight/ten/
		two/eight/ten/eleven.txt two/eight/ten/twelve.txt };
	
	dotest($recur,\@exp,['--recursive']);
}

done_testing;
