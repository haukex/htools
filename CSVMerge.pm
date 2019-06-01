#perl
package CSVMerge;
use warnings;
use strict;
use feature 'state';
use Carp;
use Hash::Util qw/lock_keys/;
use Data::Dump qw/pp/;
use Data::Compare qw/Compare/;
use Text::CSV; # also install Text::CSV_XS for speed
use Exporter 'import';

=head1 SYNOPSIS

B<Backend for F<csvmerge>.>

=head1 AUTHOR, COPYRIGHT, AND LICENSE

Copyright (c) 2019 Hauke Daempfling (haukex@zero-g.net)
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

our $VERSION = '0.01';

our @EXPORT_OK = qw/csvmerge/;

my %CSVMERGE_KNOWN_ARGS = map {$_=>1} qw/ files headercnt outfile
	append quotechar sepchar checkcols numcols failsoft /;
sub csvmerge {
	croak "bad number of arguments to csvmerge" unless @_%2==0;
	my %opts = @_;
	for ( keys %opts ) { croak "unknown option $_" unless $CSVMERGE_KNOWN_ARGS{$_} }
	lock_keys %opts, keys %CSVMERGE_KNOWN_ARGS;
	$opts{headercnt}//=1;
	$opts{quotechar}//='"';
	$opts{sepchar}//=',';
	croak 'Bad headercnt value' unless $opts{headercnt}=~/\A(?!0)[0-9]+\z/;
	croak 'Can\'t use outfile and append together' if defined $opts{outfile} && $opts{append};
	if (defined $opts{numcols}) {
		croak 'Bad numcols value' unless $opts{numcols}=~/\A(?!0)[0-9]+\z/;
		$opts{checkcols} = undef }
	my @files = $opts{files} && @{$opts{files}} ? @{$opts{files}} : ('-');
	warn "Warning: Only one file, nothing to csvmerge\n" if @files<2;
	state $csv = Text::CSV->new({ binary=>1, auto_diag=>2, eol=>$/,
		quote_char=>$opts{quotechar}, sep_char=>$opts{sepchar} });
		# other potentially useful options:
		# blank_is_undef=>1, allow_whitespace=>1, always_quote=>1
	my $ofh = *STDOUT;
	if ( defined $opts{outfile} )
		{ open $ofh, '>', $opts{outfile} or die "$opts{outfile}: $!" }
	my $headers; # first is 1
	my $firstfile=1;
	my @procdfiles;
	FILE: for my $file (@files) {
		my $ap = $firstfile && $opts{append};
		eval {
			my $fh;
			if ( $file eq '-' ) {
				die "Can't use append on STDIN\n" if $ap;
				$fh = *STDIN }
			else { open $fh, $ap?'+<':'<', $file or die "$file: $!" }
			my $i=1;
			ROW: while ( my $row = $csv->getline($fh) ) {
				if ( $i<=$opts{headercnt} ) {
					if ( $firstfile )
						{ $headers->[$i] = $row }
					else {
						next ROW if Compare( $headers->[$i], $row );
						die "header ".pp($row)." doesn't match ".pp($headers->[$i]);
					}
				}
				else {
					die "bad nr of columns in $file: expected $opts{numcols}, got ".@$row
						if defined $opts{numcols} && $opts{numcols}!=@$row;
				}
				die "bad nr of columns in $file: expected ".@{$headers->[1]}.", got ".@$row
					if $opts{checkcols} && @{$headers->[1]}!=@$row;
				$csv->print($ofh, $row) unless $ap;
			} continue { $i++ }
			$csv->eof or $csv->error_diag;
			if ($ap) { $ofh = $fh }
			else { close $fh }
			push @procdfiles, $file;
		1 } or do {
			chomp( my $msg = "Failure on $file: ".($@||'unknown error') );
			if ( !$opts{failsoft} || $firstfile ) { die "$msg - Aborting\n" }
			else { warn "$msg - Continuing\n" }
		};
	} continue { $firstfile=0 }
	return wantarray ? @procdfiles : scalar @procdfiles;
}

1;
