#!/usr/bin/env perl
use warnings;
use 5.016; no feature 'switch';
use utf8; # U+20AC EURO SIGN: €
use warnings FATAL=>'utf8';
use open qw/:std :utf8/;
use Test::More;

=head1 SYNOPSIS

Tests for F<enctool>.

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
use Cwd 'getcwd';
use FindBin;
use IPC::Run3::Shell ':FATAL';

use Test::Perl::Critic -severity=>3, -verbose=>9,
	-exclude => [];
use Test::Pod;

my $ENCTOOL = Path::Class::Dir->new($FindBin::Bin)->parent
	->file('enctool')->stringify;
IPC::Run3::Shell->import([ enctool =>
	{ show_cmd => Test::More->builder->output },
	$^X, $ENCTOOL ]);
local $ENV{ENCTOOL_ENCODINGS} = ""; # in case the user has something set

my $WORKDIR = Path::Class::Dir->new( $FindBin::Bin, 'enctool_tests' );
$WORKDIR->mkpath(1);
my $PREVDIR = getcwd;
END { chdir $PREVDIR if defined $PREVDIR }
note "Working in $WORKDIR";
chdir $WORKDIR or die "chdir $WORKDIR: $!";

critic_ok("$FindBin::Bin/$FindBin::Script");
critic_ok($ENCTOOL);
pod_file_ok("$FindBin::Bin/$FindBin::Script");
pod_file_ok($ENCTOOL);

my @files;
push @files, spew('ascii.txt',     "Hello, World!\n",       'ascii');
push @files, spew('latin1.txt',    "Hëll¤, Wörld¡\n",       'latin1');
push @files, spew('latin9.txt',    "H€llø, Wœrld¡\n",       'latin9');
push @files, spew('latinctl.txt',  "Hällö, Wörld¡\N{U+8D}", 'latin1'); # control code, valid latin1 & 9, not cp1252
push @files, spew('cp1252.txt',    "H€ll•, Wœrld†\r\n",     'cp1252');
push @files, spew('macroman.txt',  "Hèll∞, Wœrld¡\r",       'MacRoman');
push @files, spew('shiftjis.txt',  "Hello, 世界！\n",       'shiftjis');
push @files, spew('koi8r.txt',     "Hello, мир!\n",         'koi8-r');
push @files, spew('gsm0338.txt',   "Héllò, WΦrld!\n",       'gsm0338');
push @files, spew('ebcdic.txt',    "Hello, World!\n",       'posix-bc');
push @files, spew('utf-8.txt',     "H∃llⓄ, 🗺!\n",        'UTF-8');
push @files, spew('utf-16be.txt',  "H∃llⓄ, 🗺!\n",        'UTF-16BE');
push @files, spew('utf-16le.txt',  "H∃llⓄ, 🗺!\n",        'UTF-16LE');
push @files, spew('utf-32be.txt',  "H∃llⓄ, 🗺!\n",        'UTF-32BE');
push @files, spew('utf-32le.txt',  "H∃llⓄ, 🗺!\n",        'UTF-32LE');
my $encodings = 'ascii,latin1,latin9,cp1252,MacRoman,shiftjis,KOI8-R,gsm0338,posix-bc,UTF-8,UTF-16BE,UTF-16LE,UTF-32BE,UTF-32LE';

# perl -wMstrict -le 'print join("",glob("{C,L,CL,}{C,L,CL,}x"))'
my $crlf = ( "CCxCLxCCLxCxLCxLLxLCLxLxCLCxCLLxCLCLxCLxCxLxCLxx"
	=~ tr/CL/\x0D\x0A/r );
spew('crlf.txt', $crlf, 'ascii');
spew('ctrls.txt', join("",map {chr} 0..8,10..12,14..31 ), 'ascii');

is enctool(@files), <<'END_OUT', 'basic test, defaults';
ascii.txt: Valid ASCII, LF
latin1.txt: Valid ISO-8859-1, LF
latin9.txt: Valid ISO-8859-1, LF
latinctl.txt: probably binary, skipping (use -b to override)
cp1252.txt: Valid ISO-8859-1, CRLF; 4 Ctrls (not NUL/CR/LF/Tab)
macroman.txt: Valid ISO-8859-1, CR; 1 Ctrls (not NUL/CR/LF/Tab)
shiftjis.txt: Valid ISO-8859-1, LF; 3 Ctrls (not NUL/CR/LF/Tab)
koi8r.txt: Valid ISO-8859-1, LF
gsm0338.txt: Valid ASCII, LF; 3 Ctrls (not NUL/CR/LF/Tab)
ebcdic.txt: probably binary, skipping (use -b to override)
utf-8.txt: Valid UTF-8, LF
utf-16be.txt: probably binary, skipping (use -b to override)
utf-16le.txt: probably binary, skipping (use -b to override)
utf-32be.txt: probably binary, skipping (use -b to override)
utf-32le.txt: probably binary, skipping (use -b to override)
END_OUT

is enctool("--encodings=$encodings", @files), <<'END_OUT', 'all --encodings';
ascii.txt: Valid ASCII, LF
latin1.txt: Valid ISO-8859-1, LF
latin9.txt: Valid ISO-8859-1, LF
latinctl.txt: Valid ISO-8859-1, no CR or LF; 1 Ctrls (not NUL/CR/LF/Tab)
cp1252.txt: Valid ISO-8859-1, CRLF; 4 Ctrls (not NUL/CR/LF/Tab)
macroman.txt: Valid ISO-8859-1, CR; 1 Ctrls (not NUL/CR/LF/Tab)
shiftjis.txt: Valid ISO-8859-1, LF; 3 Ctrls (not NUL/CR/LF/Tab)
koi8r.txt: Valid ISO-8859-1, LF
gsm0338.txt: Valid ASCII, LF; 3 Ctrls (not NUL/CR/LF/Tab)
ebcdic.txt: Valid ISO-8859-1, no CR or LF; 9 Ctrls (not NUL/CR/LF/Tab)
utf-8.txt: Valid ISO-8859-1, LF; 6 Ctrls (not NUL/CR/LF/Tab)
utf-16be.txt: Valid ISO-8859-1, LF; 7 NULs, 1 Ctrls (not NUL/CR/LF/Tab)
utf-16le.txt: Valid ISO-8859-1, LF; 7 NULs, 1 Ctrls (not NUL/CR/LF/Tab)
utf-32be.txt: Valid ISO-8859-1, LF; 26 NULs, 2 Ctrls (not NUL/CR/LF/Tab)
utf-32le.txt: Valid ISO-8859-1, LF; 26 NULs, 2 Ctrls (not NUL/CR/LF/Tab)
END_OUT

is enctool("--encodings=$encodings",'-NKHl', @files), <<'END_OUT', '--no-control and --all-of';
ascii.txt: Valid ASCII, LF
latin1.txt: Valid ISO-8859-1, LF
latin9.txt: Valid ISO-8859-1, LF
latinctl.txt: Valid MacRoman, no CR or LF
cp1252.txt: Valid CP1252, CRLF
macroman.txt: Valid MacRoman, CR
shiftjis.txt: Valid MacRoman, LF
koi8r.txt: Valid ISO-8859-1, LF
gsm0338.txt: Valid gsm0338, LF
ebcdic.txt: Valid posix-bc, LF
utf-8.txt: Valid CP1252, LF
utf-16be.txt: Valid UTF-16BE, LF
utf-16le.txt: Valid UTF-16LE, LF
utf-32be.txt: Valid UTF-32BE, LF
utf-32le.txt: Valid UTF-32LE, LF
END_OUT

## no critic (ProhibitComplexRegexes)
like enctool('-Ad','-KHelo','ascii.txt'), qr{
		\A ascii\.txt: \n
		(?: (\s+)Valid\ \S+,\ LF\n
		    \1\1"Hello,\ World!\\n"\n
		)+ \z }mx, '--all with ASCII';
## use critic

is enctool("--encodings=$encodings",'-k\\N{EURO SIGN}', 'latin9.txt'),
	"latin9.txt: Valid ISO-8859-15, LF\n", 'guided latin9 detection';

is enctool("--encodings=cp1252,latin1",'-bk\\N{U+8D}', 'latinctl.txt'),
	"latinctl.txt: Valid ISO-8859-1, no CR or LF; 1 Ctrls (not NUL/CR/LF/Tab)\n",
		'guided latin1/9 vs. cp1252 detection';

is enctool("--encodings=$encodings", '-N', 'cp1252.txt'),
	"cp1252.txt: Valid CP1252, CRLF\n", 'guided cp1252 detection';

is enctool("--encodings=$encodings", '-k\\p{Script=Han}', 'shiftjis.txt'),
	"shiftjis.txt: Valid shiftjis, LF\n", 'guided shiftjis detection';

is enctool("--encodings=$encodings", '-k\\p{Script=Cyrillic}', 'koi8r.txt'),
	"koi8r.txt: Valid KOI8-R, LF\n", 'guided koi8-r detection';

is enctool('-Ed','-k\\N{WORLD MAP}',glob("utf-{8,16be,16le,32be,32le}.txt")), <<'END_OUT', 'guided UTF-* detection';
utf-8.txt: Valid UTF-8, LF
    "H\x{2203}ll\x{24c4}, \x{1f5fa}!\n"
utf-16be.txt: Valid UTF-16, LF
    "H\x{2203}ll\x{24c4}, \x{1f5fa}!\n"
utf-16le.txt: Valid UTF-16LE, LF
    "H\x{2203}ll\x{24c4}, \x{1f5fa}!\n"
utf-32be.txt: Valid UTF-32, LF
    "H\x{2203}ll\x{24c4}, \x{1f5fa}!\n"
utf-32le.txt: Valid UTF-32LE, LF
    "H\x{2203}ll\x{24c4}, \x{1f5fa}!\n"
END_OUT

# this test assumes the locale is UTF-8 and therefore the enctool will output in UTF-8:
my $lc_out = enctool('--encodings=latin9', '--list-chars', '--dump-raw', 'latin9.txt');
utf8::decode($lc_out);
is $lc_out, <<'END_OUT', '--list-chars and --dump-raw';
latin9.txt: Valid ISO-8859-15, LF
---8<---
H€llø, Wœrld¡
--->8---
    pos 2: U+20AC EURO SIGN ("€")
    pos 5: U+F8 LATIN SMALL LETTER O WITH STROKE ("ø")
    pos 9: U+153 LATIN SMALL LIGATURE OE ("œ")
    pos 13: U+A1 INVERTED EXCLAMATION MARK ("¡")
END_OUT

## no critic (ProhibitComplexRegexes)
like enctool("--encodings=ascii,latin9,cp1252", '-fg', '-N', 'latin9.txt'), qr{
\A \Qlatin9.txt:
    Encode::Guess could not decide: \E
		(?: \Qiso-8859-15 or cp1252\E | \Qcp1252 or iso-8859-15\E ) \Q
    file(1) thinks it is "iso-8859-1", added to list of tests
    Valid ISO-8859-15, LF\E \Z
}xms, '--use-file and --encode-guess';
## use critic

is enctool("--encodings=$encodings",'--full-file','--ignore-plain','-NKHl', @files), <<'END_OUT', '--full-file and --ignore-plain';
latin1.txt: Valid ISO-8859-1, LF; file(1): ISO-8859 text
latin9.txt: Valid ISO-8859-1, LF; file(1): ISO-8859 text
latinctl.txt: Valid MacRoman, no CR or LF; file(1): Non-ISO extended-ASCII text, with no line terminators
cp1252.txt: Valid CP1252, CRLF; file(1): Non-ISO extended-ASCII text, with CRLF line terminators
macroman.txt: Valid MacRoman, CR; file(1): Non-ISO extended-ASCII text, with CR line terminators
shiftjis.txt: Valid MacRoman, LF; file(1): Non-ISO extended-ASCII text
koi8r.txt: Valid ISO-8859-1, LF; file(1): ISO-8859 text
gsm0338.txt: Valid gsm0338, LF; file(1): data
ebcdic.txt: Valid posix-bc, LF; file(1): EBCDIC text, with NEL line terminators
utf-8.txt: Valid CP1252, LF; file(1): UTF-8 Unicode text
utf-16be.txt: Valid UTF-16BE, LF; file(1): data
utf-16le.txt: Valid UTF-16LE, LF; file(1): data
utf-32be.txt: Valid UTF-32BE, LF; file(1): data
utf-32le.txt: Valid UTF-32LE, LF; file(1): data
END_OUT

is enctool('-upN', 'ascii.txt', 'utf-8.txt', 'cp1252.txt'), <<'END_OUT', '--ignore-plain and --ignore-utf-8';
cp1252.txt: Valid CP1252, CRLF
END_OUT

is enctool('-b','crlf.txt','ctrls.txt'), <<'END_OUT', 'CR/LF/Ctrl';
crlf.txt: Valid ASCII, MIXED: 7 CRs, 7 LFs, 9 CRLFs
ctrls.txt: Valid ASCII, LF; 1 NULs, 28 Ctrls (not NUL/CR/LF/Tab)
END_OUT
is enctool('-bp', 'ascii.txt','crlf.txt','ctrls.txt'), <<'END_OUT', 'CR/LF/Ctrl and -p';
crlf.txt: Valid ASCII, MIXED: 7 CRs, 7 LFs, 9 CRLFs
ctrls.txt: Valid ASCII, LF; 1 NULs, 28 Ctrls (not NUL/CR/LF/Tab)
END_OUT
is enctool('-bV', 'crlf.txt','ctrls.txt'), <<'END_OUT', 'CR/LF/Ctrl and -V';
crlf.txt:
    Testing: ASCII, UTF-8, ISO-8859-1, CP1252
    Valid ASCII, MIXED: 7 CRs, 7 LFs, 9 CRLFs
ctrls.txt:
    Testing: ASCII, UTF-8, ISO-8859-1, CP1252
    Valid ASCII, 1 LFs; 1 NULs, 28 Ctrls (not NUL/CR/LF/Tab)
Of 2 files, 0 had errors, and 0 were skipped
END_OUT

done_testing;

sub spew {
	my ($fn,$content,$enc) = @_;
	open my $fh, '>:raw'.($enc?":encoding($enc)":''), $fn or die "open $fn: $!";
	print $fh $content or die "print $fn: $!";
	close $fh or die "close $fn: $!";
	return $fn;
}

__END__

=begin comment

See the differences between encodings:

 use Data::Dump;
 use Encode qw/decode/;
 use charnames ':full';
 my @encs = qw{ latin1 Latin-9 CP-1252 };
 my (%names,%codes);
 for my $i (0..255) {
 	for my $enc (@encs) {
 		my $chr; eval { $chr = decode($enc, chr($i),
 			Encode::FB_CROAK|Encode::LEAVE_SRC ); 1 } or next;
 		die unless length($chr)==1; # double-check
 		push @{$names{sprintf("U+%02X",ord($chr))." "
 			.charnames::viacode(ord($chr))}{sprintf "%02X", $i}}, $enc;
 		push @{$codes{sprintf "%02X", $i}}, $enc;
 	}
 }
 for my $n (keys %names) {
 	my @k = keys %{$names{$n}};
 	delete $names{$n} if @k==1 && @{$names{$n}{$k[0]}}==@encs;
 }
 @{$codes{$_}}==@encs and delete $codes{$_} for keys %codes;
 dd \%names; dd \%codes;

Some research on the Unicode "Control" characters:

 use Data::Dump;
 use Unicode::UCD qw/charprop prop_invlist/;
 use charnames ':full';
 # see the docs of prop_invlist for description of the return values:
 print join(", ", map {sprintf "%02X", $_} prop_invlist("General_Category=Control")), "\n";
 for my $c (0..255) {
 	my $gc = charprop($c, 'General_Category');
 	my $ws = charprop($c, 'White_Space');
 	next unless $gc eq 'Control'; # && $ws ne 'No';
 	dd sprintf('%02X',$c), charnames::viacode($c), $gc, $ws;
 }

=end comment

=cut
