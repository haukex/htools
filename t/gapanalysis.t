#!/usr/bin/env perl
use warnings;
use 5.018;
use Test::More tests=>17;
use FindBin;
use File::Spec::Functions qw/catfile/;
use Time::Piece;
use IPC::Run3::Shell ':FATAL',
	[ gapan => {chomp=>1, fail_on_stderr=>1},
		catfile($FindBin::Bin,'..','gapanalysis') ];

# SEE THE END OF THIS FILE FOR AUTHOR, COPYRIGHT AND LICENSE INFORMATION

# ### Basic Tests ###
# (a couple of "reverse"s etc. to show order doesn't matter)
my $stdin1 = join '', map { "$_\n" }
	        3,1,2,    # no gap
	reverse(4..6),    # gap 1: 7
	        8..10,    # gap 2: 11, 12
	reverse(13..15,   # gap 3: 16..18
	reverse(19..21),  # gap 4: 22..25
	        27,26,28, # gap 5: 29..33
	        34..36);
is_deeply [gapan({stdin=>\$stdin1})],
	["1\t6","8\t10","13\t15","19\t21","26\t28","34\t36"], 'default -g1';
is_deeply [gapan({stdin=>\$stdin1},'-g1')],
	["1\t6","8\t10","13\t15","19\t21","26\t28","34\t36"], '-g1';
is_deeply [gapan({stdin=>\$stdin1},'-g2')],
	["1\t10","13\t15","19\t21","26\t28","34\t36"], '-g2';
is_deeply [gapan({stdin=>\$stdin1},'-g3')],
	["1\t15","19\t21","26\t28","34\t36"], '-g3';
is_deeply [gapan({stdin=>\$stdin1},'-g4')],
	["1\t21","26\t28","34\t36"], '-g4';
is_deeply [gapan({stdin=>\$stdin1},'-g5')],
	["1\t28","34\t36"], '-g5';
is_deeply [gapan({stdin=>\$stdin1},'-g6')],
	["1\t36"], '-g6';

# ### Test with $PAD=60 ###
# difference: $PAD = 60  => merged
is_deeply [gapan({stdin=>\"120\n180"},'--gap=122')], ["120\t180"];
# difference: 2*$PAD = 120  => merged
is_deeply [gapan({stdin=>\"120\n240"},'--gap=122')], ["120\t240"];
# difference: 2*$PAD+1 = 121  => still merged
# (because the padded [60,180],[181,301] is merged to [60,301])
is_deeply [gapan({stdin=>\"120\n241"},'--gap=122')], ["120\t241"];
# difference: 2*$PAD+2 = 122  => still merged
# (because *between* 120 and 242, there are 121 integers)
is_deeply [gapan({stdin=>\"120\n242"},'--gap=122')], ["120\t242"];
# difference: 2*$PAD+3 = 123  => NOT merged
is_deeply [gapan({stdin=>\"120\n243"},'--gap=122')], ["120\t120","243\t243"];

# ### Test of -f and -F ###
my $stdin2 = join '', map { "X $_ Y\n" } 1,2,3,6,7,8;
is_deeply [gapan({stdin=>\$stdin2},'--f=2')], ["1\t3","6\t8"];
my $stdin3 = join '', map { "A,$_,C\n" } 1,2,3,6,7,8;
is_deeply [gapan({stdin=>\$stdin3},'--f=2','-F,')], ["1\t3","6\t8"];

# ### Test of -h and -H ###
my $stdin4 = join "\n", 1,2,3,7,8,9,13,14,15;
is_deeply [gapan({stdin=>\$stdin4},'--holes')],
	["Span\t1\t3","Hole\t4\t6","Span\t7\t9","Hole\t10\t12","Span\t13\t15"];
is_deeply [gapan({stdin=>\$stdin4},'-H')], ["4\t6","10\t12"];

# ### Test of --time ###
my $stdin5 = join "\n",
	map { Time::Piece->strptime($_,"%Y-%m-%dT%H:%M:%S")->epoch }
	"2019-06-04T12:00:01",
	"2019-06-04T12:01:00",
	"2019-06-04T12:02:00",
	"2019-06-04T12:03:05",
	"2019-06-04T12:04:00",
	"2019-06-04T12:04:58",
	"2019-06-04T12:06:00",
	"2019-06-04T12:07:00";
is_deeply [gapan({stdin=>\$stdin5},'--gap=60','--time')],[
	"2019-06-04T12:00:01\t2019-06-04T12:02:00",
	"2019-06-04T12:03:05\t2019-06-04T12:04:58",
	"2019-06-04T12:06:00\t2019-06-04T12:07:00"];


__END__

=head1 Author, Copyright, and License

Copyright (c) 2019 Hauke Daempfling (haukex@zero-g.net)
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
