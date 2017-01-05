#!/usr/bin/env perl
use warnings FATAL=>'all';
use strict;
use 5.010; no feature 'switch';

=head1 SYNOPSIS

B<Tests for the F<relink> script.>

Note: Assumes *NIX style paths (forward slashes).

=head1 AUTHOR, COPYRIGHT, AND LICENSE

Copyright (c) 2017 Hauke Daempfling (haukex@zero-g.net)
at the Leibniz Institute of Freshwater Ecology and Inland Fisheries (IGB),
Berlin, Germany, L<http://www.igb-berlin.de/>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see L<http://www.gnu.org/licenses/>.

=cut

use Test::More;
use Test::Perl::Critic -severity=>3, -verbose=>9,
	-exclude => ['ProhibitExcessMainComplexity','ProhibitMixedBooleanOperators'];
use Test::Pod;

use Carp;
use FindBin;
use File::Spec::Functions qw/ file_name_is_absolute rel2abs /;
use File::Basename 'fileparse';
use File::Temp qw/ tempdir /;
use File::Path 'make_path';
use File::Find qw/find/;
use File::stat;
use Fcntl ':mode';
use Cwd qw/abs_path getcwd/;
use IPC::Run3 'run3';

eval { symlink("",""); 1 }
	or BAIL_OUT("Your system does not support symlinks.");

my $PREVDIR = getcwd;
END { chdir $PREVDIR if defined $PREVDIR }

my $RELINK = "$FindBin::Bin/../relink";
critic_ok("$FindBin::Bin/$FindBin::Script");
critic_ok($RELINK);
pod_file_ok("$FindBin::Bin/$FindBin::Script");
pod_file_ok($RELINK);

$ENV{RELINK_SORTED_FIND} = 1;  ## no critic (RequireLocalizedPunctuationVars)

sub setup_new_dir {
	croak "too many arguments to setup_new_dir" if @_;
	my $dir;
	my $cnt=0;
	GETDIR: {
		$dir = tempdir(CLEANUP=>1);
		croak "relative tempdir? $dir" unless file_name_is_absolute($dir);
		# There's a tiny chance that strings used in the rewrite
		# tests could appear in the temporary pathname,
		# in that case just generate a new temp dir name.
		confess "what are the odds? $dir" if $cnt++>10;
		if ($dir=~/dead|not/) {
			diag "redoing $dir";
			redo GETDIR }
	}
	chdir $dir or croak "chdir '$dir' failed: $!";
	make_path('foo','bar')==2 or croak 'make_path';
	touch('foo/one','bar/two','bar/notdead');
	mklink('foo/aaa','one');
	mklink('foo/bbb','../bar/two');
	mklink('bar/ccc',"$dir/foo/one");
	mklink('bar/ddd',"$dir/bar/two");
	mklink('foo/eee','dead');
	mklink('foo/fff','../bar/notnotdead');
	mklink('bar/ggg',"$dir/foo/dead");
	mklink('bar/hhh','notdead');
	mklink('bar/iii',"$dir/bar/ddd");
	mklink('bar/jjj','../foo/bbb');
	is list({all=>1},'.'), <<"ENDLIST", "setup_new_dir $dir";
$dir/
$dir/bar/
$dir/bar/ccc -> $dir/foo/one
$dir/bar/ddd -> $dir/bar/two
$dir/bar/ggg X> $dir/foo/dead
$dir/bar/hhh -> notdead
$dir/bar/iii -> $dir/bar/ddd
$dir/bar/jjj -> ../foo/bbb
$dir/bar/notdead
$dir/bar/two
$dir/foo/
$dir/foo/aaa -> one
$dir/foo/bbb -> ../bar/two
$dir/foo/eee X> dead
$dir/foo/fff X> ../bar/notnotdead
$dir/foo/one
ENDLIST
	return $dir;
}

subtest 'list tests' => sub {
	my $dir = setup_new_dir();
	subtest 'list' => mksubtest_relink(['list','--',$dir],<<"STDOUT",'');
$dir/bar/ccc -> $dir/foo/one
$dir/bar/ddd -> $dir/bar/two
$dir/bar/ggg X> $dir/foo/dead
$dir/bar/hhh -> notdead
$dir/bar/iii -> $dir/bar/ddd
$dir/bar/jjj -> ../foo/bbb
$dir/foo/aaa -> one
$dir/foo/bbb -> ../bar/two
$dir/foo/eee X> dead
$dir/foo/fff X> ../bar/notnotdead
STDOUT
	subtest 'list relative' => mksubtest_relink(['list'],<<"STDOUT",'');
./bar/ccc -> $dir/foo/one
./bar/ddd -> $dir/bar/two
./bar/ggg X> $dir/foo/dead
./bar/hhh -> notdead
./bar/iii -> $dir/bar/ddd
./bar/jjj -> ../foo/bbb
./foo/aaa -> one
./foo/bbb -> ../bar/two
./foo/eee X> dead
./foo/fff X> ../bar/notnotdead
STDOUT
	subtest 'list -v' => mksubtest_relink(['list','-v','--',$dir],<<"STDOUT",'');
$dir/bar/ccc -> $dir/foo/one (-> $dir/foo/one)
$dir/bar/ddd -> $dir/bar/two (-> $dir/bar/two)
$dir/bar/ggg X> $dir/foo/dead (X> $dir/foo/dead)
$dir/bar/hhh -> notdead (-> $dir/bar/notdead)
$dir/bar/iii -> $dir/bar/ddd (-> $dir/bar/ddd)
$dir/bar/jjj -> ../foo/bbb (-> $dir/foo/bbb)
$dir/foo/aaa -> one (-> $dir/foo/one)
$dir/foo/bbb -> ../bar/two (-> $dir/bar/two)
$dir/foo/eee X> dead (X> $dir/foo/dead)
$dir/foo/fff X> ../bar/notnotdead (X> $dir/bar/notnotdead)
STDOUT
	if (-t Test::More->builder->output) {  ## no critic (ProhibitInteractiveTest)
		my $colorout;
		ok run3([$RELINK,'list','-vc','--',$dir], undef, \$colorout, \$colorout), 'list -v color demo';
		is $?, 0, 'list -v color exit code';
		note "Demo of color output from 'list -v':\n", $colorout;
	}
	subtest 'list -b' => mksubtest_relink(['list','-b','--',$dir],<<"STDOUT",'');
$dir/bar/ggg X> $dir/foo/dead
$dir/foo/eee X> dead
$dir/foo/fff X> ../bar/notnotdead
STDOUT
	subtest 'list -B' => mksubtest_relink(['list','-B','--',$dir],<<"STDOUT",'');
$dir/bar/ccc -> $dir/foo/one
$dir/bar/ddd -> $dir/bar/two
$dir/bar/hhh -> notdead
$dir/bar/iii -> $dir/bar/ddd
$dir/bar/jjj -> ../foo/bbb
$dir/foo/aaa -> one
$dir/foo/bbb -> ../bar/two
STDOUT
};

subtest 'rel2abs tests' => sub {
	my $dir = setup_new_dir();
	subtest 'rel2abs -B' => mksubtest_relink(['rel2abs','-B'],'','');
	is list('.'), <<"ENDLIST", 'rel2abs -B result';
$dir/bar/ccc -> $dir/foo/one
$dir/bar/ddd -> $dir/bar/two
$dir/bar/ggg X> $dir/foo/dead
$dir/bar/hhh -> $dir/bar/notdead
$dir/bar/iii -> $dir/bar/ddd
$dir/bar/jjj -> $dir/foo/bbb
$dir/foo/aaa -> $dir/foo/one
$dir/foo/bbb -> $dir/bar/two
$dir/foo/eee X> dead
$dir/foo/fff X> ../bar/notnotdead
ENDLIST
	subtest 'rel2abs' => mksubtest_relink(['rel2abs'],'','');
	is list('.'), <<"ENDLIST", 'rel2abs result';
$dir/bar/ccc -> $dir/foo/one
$dir/bar/ddd -> $dir/bar/two
$dir/bar/ggg X> $dir/foo/dead
$dir/bar/hhh -> $dir/bar/notdead
$dir/bar/iii -> $dir/bar/ddd
$dir/bar/jjj -> $dir/foo/bbb
$dir/foo/aaa -> $dir/foo/one
$dir/foo/bbb -> $dir/bar/two
$dir/foo/eee X> $dir/foo/dead
$dir/foo/fff X> $dir/bar/notnotdead
ENDLIST
};

subtest 'abs2rel tests' => sub {
	my $dir = setup_new_dir();
	subtest 'abs2rel -B' => mksubtest_relink(['abs2rel','-B'],'','');
	is list('.'), <<"ENDLIST", 'abs2rel -B result';
$dir/bar/ccc -> ../foo/one
$dir/bar/ddd -> two
$dir/bar/ggg X> $dir/foo/dead
$dir/bar/hhh -> notdead
$dir/bar/iii -> ddd
$dir/bar/jjj -> ../foo/bbb
$dir/foo/aaa -> one
$dir/foo/bbb -> ../bar/two
$dir/foo/eee X> dead
$dir/foo/fff X> ../bar/notnotdead
ENDLIST
	subtest 'abs2rel -b' => mksubtest_relink(['abs2rel','-b'],'','');
	is list('.'), <<"ENDLIST", 'abs2rel -b result';
$dir/bar/ccc -> ../foo/one
$dir/bar/ddd -> two
$dir/bar/ggg X> ../foo/dead
$dir/bar/hhh -> notdead
$dir/bar/iii -> ddd
$dir/bar/jjj -> ../foo/bbb
$dir/foo/aaa -> one
$dir/foo/bbb -> ../bar/two
$dir/foo/eee X> dead
$dir/foo/fff X> ../bar/notnotdead
ENDLIST
};

subtest 'targ tests' => sub {
	my $dir = setup_new_dir();
	# Test the use case mentioned in the docs
	subtest 'list -vt' => mksubtest_relink(['list','-vt','$FULL=~/^$PATHS/','--',"$dir/bar"],<<"STDOUT",'');
$dir/bar/ddd -> $dir/bar/two (-> $dir/bar/two)
$dir/bar/hhh -> notdead (-> $dir/bar/notdead)
$dir/bar/iii -> $dir/bar/ddd (-> $dir/bar/ddd)
$dir/bar/jjj -> ../foo/bbb (-> $dir/foo/bbb)
STDOUT
	# Only apply "rel2abs" on those links whose target (unchanged,
	# i.e. as returned by readlink) matches the regex
	subtest 'rel2abs -t' => mksubtest_relink(['rel2abs','-t','m{bar/two|dead}'],'','');
	is list('.'), <<"ENDLIST", 'rel2abs -t result';
$dir/bar/ccc -> $dir/foo/one
$dir/bar/ddd -> $dir/bar/two
$dir/bar/ggg X> $dir/foo/dead
$dir/bar/hhh -> $dir/bar/notdead
$dir/bar/iii -> $dir/bar/ddd
$dir/bar/jjj -> ../foo/bbb
$dir/foo/aaa -> one
$dir/foo/bbb -> $dir/bar/two
$dir/foo/eee X> $dir/foo/dead
$dir/foo/fff X> $dir/bar/notnotdead
ENDLIST
};

subtest 'rewrite (all)' => sub {
	my $dir = setup_new_dir();
	subtest 'rewrite' => mksubtest_relink(['rewrite','s/dead/one/'],'','');
	is list('.'), <<"ENDLIST", 'rewrite result';
$dir/bar/ccc -> $dir/foo/one
$dir/bar/ddd -> $dir/bar/two
$dir/bar/ggg -> $dir/foo/one
$dir/bar/hhh X> notone
$dir/bar/iii -> $dir/bar/ddd
$dir/bar/jjj -> ../foo/bbb
$dir/foo/aaa -> one
$dir/foo/bbb -> ../bar/two
$dir/foo/eee -> one
$dir/foo/fff X> ../bar/notnotone
ENDLIST
};

subtest 'rewrite -n' => sub {
	my $dir = setup_new_dir();
	subtest 'rewrite -n' => mksubtest_relink(['rewrite','-n','s/dead/one/'],<<"STDOUT",<<"STDERR");
./bar/ggg: $dir/foo/dead => $dir/foo/one
./bar/hhh: notdead => notone
./foo/eee: dead => one
./foo/fff: ../bar/notnotdead => ../bar/notnotone
STDOUT
*** REMINDER: This was a dry-run ***
STDERR
	is list('.'), <<"ENDLIST", 'rewrite -n result';
$dir/bar/ccc -> $dir/foo/one
$dir/bar/ddd -> $dir/bar/two
$dir/bar/ggg X> $dir/foo/dead
$dir/bar/hhh -> notdead
$dir/bar/iii -> $dir/bar/ddd
$dir/bar/jjj -> ../foo/bbb
$dir/foo/aaa -> one
$dir/foo/bbb -> ../bar/two
$dir/foo/eee X> dead
$dir/foo/fff X> ../bar/notnotdead
ENDLIST
	if (-t Test::More->builder->output) {  ## no critic (ProhibitInteractiveTest)
		my $colorout;
		ok run3([$RELINK,'rewrite','-nc','s/dead/one/'], undef, \$colorout, \$colorout), 'rewrite -n color demo';
		is $?, 0, 'rewrite -n color exit code';
		note "Demo of color output from 'rewrite -n':\n", $colorout;
	}
};

subtest 'rewrite -F' => sub {
	my $dir = setup_new_dir();
	subtest 'rewrite -F' => mksubtest_relink(
		['rewrite','-F','--','s/dead/one/',
		$dir, "$dir/bar/ggg", "$dir/foo/eee"],'','');
	is list('.'), <<"ENDLIST", 'rewrite -F result';
$dir/bar/ccc -> $dir/foo/one
$dir/bar/ddd -> $dir/bar/two
$dir/bar/ggg -> $dir/foo/one
$dir/bar/hhh -> notdead
$dir/bar/iii -> $dir/bar/ddd
$dir/bar/jjj -> ../foo/bbb
$dir/foo/aaa -> one
$dir/foo/bbb -> ../bar/two
$dir/foo/eee -> one
$dir/foo/fff X> ../bar/notnotdead
ENDLIST
};

subtest 'rewrite -b' => sub {
	my $dir = setup_new_dir();
	subtest 'rewrite -b' => mksubtest_relink(['rewrite','-b','s/dead/one/'],'','');
	is list('.'), <<"ENDLIST", 'rewrite -b result';
$dir/bar/ccc -> $dir/foo/one
$dir/bar/ddd -> $dir/bar/two
$dir/bar/ggg -> $dir/foo/one
$dir/bar/hhh -> notdead
$dir/bar/iii -> $dir/bar/ddd
$dir/bar/jjj -> ../foo/bbb
$dir/foo/aaa -> one
$dir/foo/bbb -> ../bar/two
$dir/foo/eee -> one
$dir/foo/fff X> ../bar/notnotone
ENDLIST
};

subtest 'rewrite -B' => sub {
	my $dir = setup_new_dir();
	subtest 'rewrite -B' => mksubtest_relink(['rewrite','-B','s/not//'],'','');
	is list('.'), <<"ENDLIST", 'rewrite -B result';
$dir/bar/ccc -> $dir/foo/one
$dir/bar/ddd -> $dir/bar/two
$dir/bar/ggg X> $dir/foo/dead
$dir/bar/hhh X> dead
$dir/bar/iii -> $dir/bar/ddd
$dir/bar/jjj -> ../foo/bbb
$dir/foo/aaa -> one
$dir/foo/bbb -> ../bar/two
$dir/foo/eee X> dead
$dir/foo/fff X> ../bar/notnotdead
ENDLIST
};

subtest 'rewrite -v' => sub {
	my $dir = setup_new_dir();
	subtest 'rewrite -vb' => mksubtest_relink(['rewrite','-vb','s/dead/one/'],<<"STDOUT",'');
./bar/ggg: $dir/foo/dead => $dir/foo/one
./foo/eee: dead => one
./foo/fff: ../bar/notnotdead => ../bar/notnotone
STDOUT
	is list('.'), <<"ENDLIST", 'rewrite -vb result';
$dir/bar/ccc -> $dir/foo/one
$dir/bar/ddd -> $dir/bar/two
$dir/bar/ggg -> $dir/foo/one
$dir/bar/hhh -> notdead
$dir/bar/iii -> $dir/bar/ddd
$dir/bar/jjj -> ../foo/bbb
$dir/foo/aaa -> one
$dir/foo/bbb -> ../bar/two
$dir/foo/eee -> one
$dir/foo/fff X> ../bar/notnotone
ENDLIST
};

subtest 'Perl code' => sub {
	my $dir = tempdir(CLEANUP=>1);
	croak "relative tempdir? $dir" unless file_name_is_absolute($dir);
	chdir $dir or croak "chdir '$dir' failed: $!";
	make_path('one','two/three')==3 or croak 'make_path';
	touch('foo');
	mklink('bar','foo');
	my $EXP_LIST = <<"ENDLIST";
$dir/
$dir/bar -> foo
$dir/foo
$dir/one/
$dir/two/
$dir/two/three/
ENDLIST
	is list({all=>1},'.'), $EXP_LIST, "simple test dir $dir";
	{ # warnings
		ok run3([$RELINK,'rewrite','-w','$x.=$y'], undef, \my $out, \my $err), 'rewrite -w run3';
		is $?, 0, 'rewrite -w exit';
		is $out, '', 'rewrite -w stdout';
		like $err, qr/^Use of uninitialized value.* in concatenation.*\*\*\* THERE WERE 1 WARNINGS \*\*\*$/s, 'rewrite -w stderr';  ## no critic (ProhibitComplexRegexes)
	}
	{ # strict
		ok run3([$RELINK,'rewrite','-s','$x'], undef, \my $out, \my $err), 'rewrite -s run3';
		isnt $?, 0, 'rewrite -s exit';
		is $out, '', 'rewrite -s stdout';
		like $err, qr/Global symbol .* requires explicit package name/s, 'rewrite -s stderr';  ## no critic (ProhibitComplexRegexes)
	}
	{ # $PATHS
		my @PATHS = ('.','two','two/three/','one');
		ok run3([$RELINK,'rewrite','print $PATHS',@PATHS], undef, \my $out, \my $err), 'rewrite PATHS run3';
		is $?, 0, 'rewrite PATHS exit';
		# note the paths will be sorted longest to shortest, then alphabetical
		my $re = join '|', map {quotemeta} 'two/three/', 'one', 'two', '.';
		is $out, ''.qr/$re/, 'rewrite PATHS stdout';
		is $err, '', 'rewrite PATHS stderr';
	}
	# make sure nothing changed
	is list({all=>1},'.'), $EXP_LIST, "recheck $dir";
};

subtest 'resolvesymlink on chains' => sub {
	my $dir = tempdir(CLEANUP=>1);
	croak "relative tempdir? $dir" unless file_name_is_absolute($dir);
	chdir $dir or croak "chdir '$dir' failed: $!";
	make_path('rp1','rp2/rp3')==3 or croak 'make_path';
	touch('rp1/t1');
	mklink('lp1','rp1');
	mklink('rp2/lp3',"$dir/rp2/rp3");
	# chain 1 (working chain)
	mklink('rp1/aa','t1');
	mklink('rp2/rp3/bb','../../lp1/aa');
	mklink('rp1/cc','../rp2/lp3/bb');
	mklink('rp2/dd',"$dir/lp1/cc");
	mklink('rp2/rp3/ee',"$dir/lp1/../rp2/lp3/../dd");
	# chain 2 (broken chain)
	mklink('x0','dead');
	mklink('rp1/x1','../x0');
	mklink('rp2/rp3/x2',"$dir/lp1/x1");
	mklink('rp2/x3','lp3/x2');
	# link to nonexistent dir
	mklink('rp1/y1','../xp1/t1');
	# link to nonexistent file, with path component
	mklink('rp2/y2','../dead');
	my $EXP_LIST = <<"ENDLIST";
$dir/
$dir/lp1 -> rp1
$dir/rp1/
$dir/rp1/aa -> t1
$dir/rp1/cc -> ../rp2/lp3/bb
$dir/rp1/t1
$dir/rp1/x1 -> ../x0
$dir/rp1/y1 X> ../xp1/t1
$dir/rp2/
$dir/rp2/dd -> $dir/lp1/cc
$dir/rp2/lp3 -> $dir/rp2/rp3
$dir/rp2/rp3/
$dir/rp2/rp3/bb -> ../../lp1/aa
$dir/rp2/rp3/ee -> $dir/lp1/../rp2/lp3/../dd
$dir/rp2/rp3/x2 -> $dir/lp1/x1
$dir/rp2/x3 -> lp3/x2
$dir/rp2/y2 X> ../dead
$dir/x0 X> dead
ENDLIST
	is list({all=>1},'.'), $EXP_LIST, "test dir $dir";
	# Depths: n  0  1  2  3  4
	#           -5 -4 -3 -2 -1
	#            p          i/f
	subtest 'basic list' => mksubtest_relink(['list'],<<"STDOUT",'');
./lp1 -> rp1
./x0 X> dead
./rp1/aa -> t1
./rp1/cc -> ../rp2/lp3/bb
./rp1/x1 -> ../x0
./rp1/y1 X> ../xp1/t1
./rp2/dd -> $dir/lp1/cc
./rp2/lp3 -> $dir/rp2/rp3
./rp2/x3 -> lp3/x2
./rp2/y2 X> ../dead
./rp2/rp3/bb -> ../../lp1/aa
./rp2/rp3/ee -> $dir/lp1/../rp2/lp3/../dd
./rp2/rp3/x2 -> $dir/lp1/x1
STDOUT
	subtest 'list -l' => mksubtest_relink(['list','-l'],<<"STDOUT",'');
./lp1 -> $dir/rp1
./x0 X> $dir/dead
./rp1/aa -> $dir/rp1/t1
./rp1/cc -> $dir/rp2/rp3/bb -> $dir/rp1/aa -> $dir/rp1/t1
./rp1/x1 -> $dir/x0 X> $dir/dead
./rp1/y1 X> $dir/rp1/../xp1/t1
./rp2/dd -> $dir/rp1/cc -> $dir/rp2/rp3/bb -> $dir/rp1/aa -> $dir/rp1/t1
./rp2/lp3 -> $dir/rp2/rp3
./rp2/x3 -> $dir/rp2/rp3/x2 -> $dir/rp1/x1 -> $dir/x0 X> $dir/dead
./rp2/y2 X> $dir/dead
./rp2/rp3/bb -> $dir/rp1/aa -> $dir/rp1/t1
./rp2/rp3/ee -> $dir/rp2/dd -> $dir/rp1/cc -> $dir/rp2/rp3/bb -> $dir/rp1/aa -> $dir/rp1/t1
./rp2/rp3/x2 -> $dir/rp1/x1 -> $dir/x0 X> $dir/dead
STDOUT
	if (-t Test::More->builder->output) {  ## no critic (ProhibitInteractiveTest)
		my $colorout;
		ok run3([$RELINK,'list','-cl'], undef, \$colorout, \$colorout), 'list -l color demo';
		is $?, 0, 'list -l color exit code';
		note "Demo of color output from 'list -l':\n", $colorout;
	}
	subtest 'list -v -d none' =>
		mksubtest_relink(['list','-v','-d','n'],<<"STDOUT",'');
./lp1 -> rp1 (-> $dir/rp1)
./x0 X> dead (X> $dir/dead)
./rp1/aa -> t1 (-> $dir/rp1/t1)
./rp1/cc -> ../rp2/lp3/bb (-> $dir/rp1/../rp2/lp3/bb)
./rp1/x1 -> ../x0 (-> $dir/rp1/../x0)
./rp1/y1 X> ../xp1/t1 (X> $dir/rp1/../xp1/t1)
./rp2/dd -> $dir/lp1/cc (-> $dir/lp1/cc)
./rp2/lp3 -> $dir/rp2/rp3 (-> $dir/rp2/rp3)
./rp2/x3 -> lp3/x2 (-> $dir/rp2/lp3/x2)
./rp2/y2 X> ../dead (X> $dir/rp2/../dead)
./rp2/rp3/bb -> ../../lp1/aa (-> $dir/rp2/rp3/../../lp1/aa)
./rp2/rp3/ee -> $dir/lp1/../rp2/lp3/../dd (-> $dir/lp1/../rp2/lp3/../dd)
./rp2/rp3/x2 -> $dir/lp1/x1 (-> $dir/lp1/x1)
STDOUT
	my $depth_path = <<"STDOUT";
./lp1 -> rp1 (-> $dir/rp1)
./x0 X> dead (X> $dir/dead)
./rp1/aa -> t1 (-> $dir/rp1/t1)
./rp1/cc -> ../rp2/lp3/bb (-> $dir/rp2/rp3/bb)
./rp1/x1 -> ../x0 (-> $dir/x0)
./rp1/y1 X> ../xp1/t1 (X> $dir/rp1/../xp1/t1)
./rp2/dd -> $dir/lp1/cc (-> $dir/rp1/cc)
./rp2/lp3 -> $dir/rp2/rp3 (-> $dir/rp2/rp3)
./rp2/x3 -> lp3/x2 (-> $dir/rp2/rp3/x2)
./rp2/y2 X> ../dead (X> $dir/dead)
./rp2/rp3/bb -> ../../lp1/aa (-> $dir/rp1/aa)
./rp2/rp3/ee -> $dir/lp1/../rp2/lp3/../dd (-> $dir/rp2/dd)
./rp2/rp3/x2 -> $dir/lp1/x1 (-> $dir/rp1/x1)
STDOUT
	subtest 'list -v (default depth)' => # default depth is "path"
		mksubtest_relink(['list','-v'],$depth_path,'');
	subtest 'list -v -d path' =>
		mksubtest_relink(['list','-v','-dpath'],$depth_path,'');
	subtest 'list -v -d 0' => # "0" should be equivalent to "path"
		mksubtest_relink(['list','-v','-d0'],$depth_path,'');
	my $depth_full = <<"STDOUT";
./lp1 -> rp1 (-> $dir/rp1)
./x0 X> dead (X> $dir/dead)
./rp1/aa -> t1 (-> $dir/rp1/t1)
./rp1/cc -> ../rp2/lp3/bb (-> $dir/rp1/t1)
./rp1/x1 -> ../x0 (X> $dir/dead)
./rp1/y1 X> ../xp1/t1 (X> $dir/rp1/../xp1/t1)
./rp2/dd -> $dir/lp1/cc (-> $dir/rp1/t1)
./rp2/lp3 -> $dir/rp2/rp3 (-> $dir/rp2/rp3)
./rp2/x3 -> lp3/x2 (X> $dir/dead)
./rp2/y2 X> ../dead (X> $dir/dead)
./rp2/rp3/bb -> ../../lp1/aa (-> $dir/rp1/t1)
./rp2/rp3/ee -> $dir/lp1/../rp2/lp3/../dd (-> $dir/rp1/t1)
./rp2/rp3/x2 -> $dir/lp1/x1 (X> $dir/dead)
STDOUT
	subtest 'list -v -d full' =>
		mksubtest_relink(['list','-v','-d','full'],$depth_full,'');
	subtest 'list -v -d inf' => # "inf" should be equivalent to "full"
		mksubtest_relink(['list','-v','-d','infinity'],$depth_full,'');
	subtest 'list -v -d 1' =>
		mksubtest_relink(['list','-v','-d','1'],<<"STDOUT",'');
./lp1 -> rp1 (-> $dir/rp1)
./x0 X> dead (X> $dir/dead)
./rp1/aa -> t1 (-> $dir/rp1/t1)
./rp1/cc -> ../rp2/lp3/bb (-> $dir/rp1/aa)
./rp1/x1 -> ../x0 (X> $dir/dead)
./rp1/y1 X> ../xp1/t1 (X> $dir/rp1/../xp1/t1)
./rp2/dd -> $dir/lp1/cc (-> $dir/rp2/rp3/bb)
./rp2/lp3 -> $dir/rp2/rp3 (-> $dir/rp2/rp3)
./rp2/x3 -> lp3/x2 (-> $dir/rp1/x1)
./rp2/y2 X> ../dead (X> $dir/dead)
./rp2/rp3/bb -> ../../lp1/aa (-> $dir/rp1/t1)
./rp2/rp3/ee -> $dir/lp1/../rp2/lp3/../dd (-> $dir/rp1/cc)
./rp2/rp3/x2 -> $dir/lp1/x1 (-> $dir/x0)
STDOUT
	subtest 'list -v -d 2' =>
		mksubtest_relink(['list','-v','-d','2'],<<"STDOUT",'');
./lp1 -> rp1 (-> $dir/rp1)
./x0 X> dead (X> $dir/dead)
./rp1/aa -> t1 (-> $dir/rp1/t1)
./rp1/cc -> ../rp2/lp3/bb (-> $dir/rp1/t1)
./rp1/x1 -> ../x0 (X> $dir/dead)
./rp1/y1 X> ../xp1/t1 (X> $dir/rp1/../xp1/t1)
./rp2/dd -> $dir/lp1/cc (-> $dir/rp1/aa)
./rp2/lp3 -> $dir/rp2/rp3 (-> $dir/rp2/rp3)
./rp2/x3 -> lp3/x2 (-> $dir/x0)
./rp2/y2 X> ../dead (X> $dir/dead)
./rp2/rp3/bb -> ../../lp1/aa (-> $dir/rp1/t1)
./rp2/rp3/ee -> $dir/lp1/../rp2/lp3/../dd (-> $dir/rp2/rp3/bb)
./rp2/rp3/x2 -> $dir/lp1/x1 (X> $dir/dead)
STDOUT
	if (-t Test::More->builder->output) {  ## no critic (ProhibitInteractiveTest)
		my $colorout;
		ok run3([$RELINK,'list','-cv','-d2'], undef, \$colorout, \$colorout), 'list -v -d2 color demo';
		is $?, 0, 'list -v -d2 color exit code';
		note "Demo of color output from 'list -v -d2':\n", $colorout;
	}
	subtest 'list -v -d 3' =>
		mksubtest_relink(['list','-v','-d','3'],<<"STDOUT",'');
./lp1 -> rp1 (-> $dir/rp1)
./x0 X> dead (X> $dir/dead)
./rp1/aa -> t1 (-> $dir/rp1/t1)
./rp1/cc -> ../rp2/lp3/bb (-> $dir/rp1/t1)
./rp1/x1 -> ../x0 (X> $dir/dead)
./rp1/y1 X> ../xp1/t1 (X> $dir/rp1/../xp1/t1)
./rp2/dd -> $dir/lp1/cc (-> $dir/rp1/t1)
./rp2/lp3 -> $dir/rp2/rp3 (-> $dir/rp2/rp3)
./rp2/x3 -> lp3/x2 (X> $dir/dead)
./rp2/y2 X> ../dead (X> $dir/dead)
./rp2/rp3/bb -> ../../lp1/aa (-> $dir/rp1/t1)
./rp2/rp3/ee -> $dir/lp1/../rp2/lp3/../dd (-> $dir/rp1/aa)
./rp2/rp3/x2 -> $dir/lp1/x1 (X> $dir/dead)
STDOUT
	subtest 'list -v -d 4' => # in our test case, -d 4 should be equivalent to "full"
		mksubtest_relink(['list','-v','-d','4'],$depth_full,'');
	subtest 'list -v -d -1' => # "-1" should be equivalent to "inf"/"full"
		mksubtest_relink(['list','-v','-d-1'],$depth_full,'');
	subtest 'list -v -d -2' =>
		mksubtest_relink(['list','-v','-d','-2'],<<"STDOUT",'');
./lp1 -> rp1 (-> $dir/rp1)
./x0 X> dead (X> $dir/dead)
./rp1/aa -> t1 (-> $dir/rp1/t1)
./rp1/cc -> ../rp2/lp3/bb (-> $dir/rp1/aa)
./rp1/x1 -> ../x0 (-> $dir/x0)
./rp1/y1 X> ../xp1/t1 (X> $dir/rp1/../xp1/t1)
./rp2/dd -> $dir/lp1/cc (-> $dir/rp1/aa)
./rp2/lp3 -> $dir/rp2/rp3 (-> $dir/rp2/rp3)
./rp2/x3 -> lp3/x2 (-> $dir/x0)
./rp2/y2 X> ../dead (X> $dir/dead)
./rp2/rp3/bb -> ../../lp1/aa (-> $dir/rp1/aa)
./rp2/rp3/ee -> $dir/lp1/../rp2/lp3/../dd (-> $dir/rp1/aa)
./rp2/rp3/x2 -> $dir/lp1/x1 (-> $dir/x0)
STDOUT
	subtest 'list -v -d -3' =>
		mksubtest_relink(['list','-v','-d','-3'],<<"STDOUT",'');
./lp1 -> rp1 (-> $dir/rp1)
./x0 X> dead (X> $dir/dead)
./rp1/aa -> t1 (-> $dir/rp1/t1)
./rp1/cc -> ../rp2/lp3/bb (-> $dir/rp2/rp3/bb)
./rp1/x1 -> ../x0 (-> $dir/x0)
./rp1/y1 X> ../xp1/t1 (X> $dir/rp1/../xp1/t1)
./rp2/dd -> $dir/lp1/cc (-> $dir/rp2/rp3/bb)
./rp2/lp3 -> $dir/rp2/rp3 (-> $dir/rp2/rp3)
./rp2/x3 -> lp3/x2 (-> $dir/rp1/x1)
./rp2/y2 X> ../dead (X> $dir/dead)
./rp2/rp3/bb -> ../../lp1/aa (-> $dir/rp1/aa)
./rp2/rp3/ee -> $dir/lp1/../rp2/lp3/../dd (-> $dir/rp2/rp3/bb)
./rp2/rp3/x2 -> $dir/lp1/x1 (-> $dir/rp1/x1)
STDOUT
	subtest 'list -v -d -4' =>
		mksubtest_relink(['list','-v','-d','-4'],<<"STDOUT",'');
./lp1 -> rp1 (-> $dir/rp1)
./x0 X> dead (X> $dir/dead)
./rp1/aa -> t1 (-> $dir/rp1/t1)
./rp1/cc -> ../rp2/lp3/bb (-> $dir/rp2/rp3/bb)
./rp1/x1 -> ../x0 (-> $dir/x0)
./rp1/y1 X> ../xp1/t1 (X> $dir/rp1/../xp1/t1)
./rp2/dd -> $dir/lp1/cc (-> $dir/rp1/cc)
./rp2/lp3 -> $dir/rp2/rp3 (-> $dir/rp2/rp3)
./rp2/x3 -> lp3/x2 (-> $dir/rp2/rp3/x2)
./rp2/y2 X> ../dead (X> $dir/dead)
./rp2/rp3/bb -> ../../lp1/aa (-> $dir/rp1/aa)
./rp2/rp3/ee -> $dir/lp1/../rp2/lp3/../dd (-> $dir/rp1/cc)
./rp2/rp3/x2 -> $dir/lp1/x1 (-> $dir/rp1/x1)
STDOUT
	subtest 'list -v -d -5' => # in our test case, d -5 should be equivalent to -d 0
		mksubtest_relink(['list','-v','-d','-5'],$depth_path,'');
	is list({all=>1},'.'), $EXP_LIST, "recheck $dir";
};

subtest 'resolvesymlink doc example' => sub {
	my $dir = tempdir(CLEANUP=>1);
	croak "relative tempdir? $dir" unless file_name_is_absolute($dir);
	chdir $dir or croak "chdir '$dir' failed: $!";
	touch('file');
	mklink('linkthree','file');
	mklink('linktwo','linkthree');
	mklink('linkone','linktwo');
	is list({all=>1},'.'), <<"ENDLIST", "test dir $dir";
$dir/
$dir/file
$dir/linkone -> linktwo
$dir/linkthree -> file
$dir/linktwo -> linkthree
ENDLIST
	subtest 'list -vd0' => mksubtest_relink(['list','-Fvd0','--',"$dir/linkone"],
		"$dir/linkone -> linktwo (-> $dir/linktwo)\n",'');
	subtest 'list -vd1' => mksubtest_relink(['list','-Fvd1','--',"$dir/linkone"],
		"$dir/linkone -> linktwo (-> $dir/linkthree)\n",'');
	subtest 'list -vd2' => mksubtest_relink(['list','-Fvd2','--',"$dir/linkone"],
		"$dir/linkone -> linktwo (-> $dir/file)\n",'');
	subtest 'list -vd3' => mksubtest_relink(['list','-Fvd3','--',"$dir/linkone"],
		"$dir/linkone -> linktwo (-> $dir/file)\n",'');
	subtest 'list -vd-1' => mksubtest_relink(['list','-Fvd-1','--',"$dir/linkone"],
		"$dir/linkone -> linktwo (-> $dir/file)\n",'');
	subtest 'list -vd-2' => mksubtest_relink(['list','-Fvd-2','--',"$dir/linkone"],
		"$dir/linkone -> linktwo (-> $dir/linkthree)\n",'');
	subtest 'list -vd-3' => mksubtest_relink(['list','-Fvd-3','--',"$dir/linkone"],
		"$dir/linkone -> linktwo (-> $dir/linktwo)\n",'');
	subtest 'list -vd-4' => mksubtest_relink(['list','-Fvd-4','--',"$dir/linkone"],
		"$dir/linkone -> linktwo (-> $dir/linktwo)\n",'');
};

done_testing;

sub mksubtest_relink {
	my ($args,$exp_out,$exp_err) = @_;
	croak "wrong nr of args to mksubtest_relink" unless @_==3;
	croak "mksubtest_relink: bad args" if @$args<1 || $$args[0] eq $RELINK;
	return sub {
		ok run3([$RELINK,@$args], undef, \my $got_out, \my $got_err), "run3 relink";
		is $?, 0, "exit code";
		is $got_out, $exp_out, "stdout";
		is $got_err, $exp_err, "stderr";
	}
}

sub mklink {
	my $from = shift;
	my $to = shift;
	croak "too many arguments to mklink" if @_;
	croak "mklink: empty name" unless length $from && length $to;
	croak "mklink: $from exists" if -e $from;
	symlink($to,$from) or croak "symlink($to,$from): $!";
	return 1;
}

sub touch {
	my (@files) = @_;
	croak "touch: no files given" unless @files;
	for my $f (@files) {
		croak "touch: empty name" unless length $f;
		croak "touch: $f exists" if -e $f;
		open my $fh, '>', $f or croak "open $f: $!";
		close $fh;
	}
	return 1;
}

sub list {
	my (@paths) = @_;
	my $opts = ref $paths[0] eq 'HASH' ? shift @paths : {};
	croak "list: no paths given" unless @paths;
	my @list;
	find({ no_chdir=>1, wanted => sub {
		my $f = $File::Find::name;
		my $lstat = lstat $f or croak "lstat $f: $!";
		if (S_ISLNK($lstat->mode)) {
			my $t = readlink($f) or croak "readlink $f: $!";
			my $rl2a = rel2abs($t, (fileparse($f))[1]);
			my $l = -l $rl2a || -e $rl2a ? '->' : 'X>';
			push @list, "$f $l $t";
		}
		elsif (S_ISDIR($lstat->mode))
			{ push @list, "$f/" if $$opts{all} }
		elsif (S_ISREG($lstat->mode))
			{ push @list, $f if $$opts{all} }
		else { croak "unexpected file type at $f" }
	}}, map {abs_path(rel2abs($_))} @paths );
	@list = sort @list;
	return wantarray ? @list : join("\n",@list,'');
}

