#!/usr/bin/env perl
use warnings;
use strict;
use FindBin;
use File::Spec::Functions qw/catdir catfile/;
use POSIX ':sys_wait_h';
use Config;
use Digest::SHA qw/sha256_hex/;
use File::Temp qw/tempfile tempdir/;
use Test::More;
use Test::Perl::Critic -severity=>3, -verbose=>9,
	-exclude => [];
use Test::Pod;

=head1 SYNOPSIS

B<Tests for F<HTTP_Tiny_FileCache.pm>.>

TODO Later: These tests could be more extensive.

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

## no critic (RequireTestLabels)

my %signals; @signals{split ' ', $Config{sig_name}} = split ' ', $Config{sig_num};

sub exception (&) {  ## no critic (ProhibitSubroutinePrototypes)
	return eval { shift->(); 1 } ? undef : ($@ || die "\$@ was false");
}
sub warns (&) {  ## no critic (ProhibitSubroutinePrototypes)
	my $sub = shift;
	my @warns;
	{ local $SIG{__WARN__} = sub { push @warns, shift };
		$sub->() }
	return @warns;
}

my ($tfh1,$serverlog) = tempfile(UNLINK=>1);
close $tfh1;
{
	package MyWebServer;
	use parent 'HTTP::Server::Simple::CGI';
	use Fcntl qw(:flock SEEK_END);
	sub handle_request {
		my ($self,$cgi) = @_;
		open my $log, '>>', $serverlog or die "$serverlog: $!";  ## no critic (RequireBriefOpen)
		flock($log, LOCK_EX) or die "flock: $!";
		seek($log, 0, SEEK_END) or die "seek: $!";
		if ( my $ims = $cgi->http('If-Modified-Since') ) {
			print "HTTP/1.0 304 Not Modified\r\n";
			print "Server: ".__PACKAGE__."\r\n";
			print "Last-Modified: Sat, 16 Nov 2019 16:41:20 GMT\r\n";
			print "\r\n";
			print $log $cgi->path_info,"\t304\n";
		}
		else {
			print "HTTP/1.0 200 OK\r\n";
			print "Server: ".__PACKAGE__."\r\n";
			print "Last-Modified: Sat, 16 Nov 2019 16:41:20 GMT\r\n";
			print $cgi->header('text/plain');
			print __PACKAGE__, $cgi->path_info;
			print $log $cgi->path_info,"\t200\n";
		}
		close $log;
		return;
	}
}
my $server = MyWebServer->new(8089);
$server->host('127.0.0.1');
my $BASE = 'http://127.0.0.1:8089';
my $pid = $server->background() or die "Failed to start up test server";
note "Web Server started with PID $pid";
END {
	my $ex = $?; # because waitpid will modify it
	if ($pid) {
		kill('TERM',$pid) or die "Failed to SIGTERM $pid: $!";
		1 while waitpid($pid, WNOHANG) == 0;
		if ( $?==0 || $?==$signals{TERM} )
			{ note "Web Server PID $pid ended normally" }
		else { warn "Web Server PID ended with \$?=$?".($?<0?", \$!=$!":'') }
	}
	$? = $ex;  ## no critic (RequireLocalizedPunctuationVars)
}

BEGIN {
	local @INC = @INC;
	unshift @INC, catdir($FindBin::Bin, '..', 'lib');
	use_ok 'HTTP_Tiny_FileCache'
};

critic_ok(__FILE__);
pod_file_ok(__FILE__);
critic_ok($INC{'HTTP_Tiny_FileCache.pm'});
pod_file_ok($INC{'HTTP_Tiny_FileCache.pm'});

my $cachedir = tempdir( TMPDIR=>1, TEMPLATE=>'HTTP_Tiny_FileCache_Tests_XXXXXXXXXX', CLEANUP=>1 );

my $checkidx = sub {
	my $exp = shift;
	my $file = catfile($cachedir, $HTTP_Tiny_FileCache::INDEX_FILE_NAME);
	open my $fh, '<', $file or die "$file: $!";
	my $got = do { local $/=undef; <$fh> };
	close $fh;
	is $got, $exp, 'index file is correct';
	unlink($file) or die "unlink($file): $!";
	return;
};

my $verbose = -t Test::More->builder->output;  ## no critic (ProhibitInteractiveTest)

{
	my $http = HTTP_Tiny_FileCache->new( cache_path=>$cachedir,
		verbose => $verbose, log_requests => $verbose );
	my ($url,$content) = ("$BASE/one",'MyWebServer/one');
	{
		my $r = $http->get($url);
		ok $r->{success};
		is $r->{status}, 200;
		is $r->{content}, $content;
		ok !exists $r->{cachefile};
		is $r->{headers}{server}, 'MyWebServer';
	}
	{
		my $r = $http->get($url);
		ok $r->{success};
		is $r->{status}, 304;
		is $r->{content}, $content;
		is $r->{cachefile}, catfile($cachedir, sha256_hex($url));
		is $r->{headers}{server}, 'MyWebServer';
	}
	{
		my $r = $http->get($url, CACHE_ALWAYS);
		ok $r->{success};
		is $r->{status}, 200;
		is $r->{reason}, '(from cache)';
		is $r->{content}, $content;
		is $r->{cachefile}, catfile($cachedir, sha256_hex($url));
		ok !exists $r->{headers};
	}
	{
		my $r = $http->get($url, CACHE_NEVER);
		ok $r->{success};
		is $r->{status}, 200;
		is $r->{content}, $content;
		ok !exists $r->{cachefile};
		is $r->{headers}{server}, 'MyWebServer';
	}
	$http = undef; # destroy to trigger flush
	$checkidx->(sha256_hex($url)."\t$url\n");
}

{
	my $http = HTTP_Tiny_FileCache->new( cache_path=>$cachedir,
		urltransform => 'clean', verbose => $verbose, log_requests => $verbose );
	my ($url,$content) = ("$BASE/two",'MyWebServer/two');
	{
		my $r = $http->get($url);
		ok $r->{success};
		is $r->{status}, 200;
		is $r->{content}, $content;
		ok !exists $r->{cachefile};
		is $r->{headers}{server}, 'MyWebServer';
	}
	{
		my $r = $http->get($url);
		ok $r->{success};
		is $r->{status}, 304;
		is $r->{content}, $content;
		is $r->{cachefile}, catfile($cachedir, 'http_127.0.0.1_8089_two');
		is $r->{headers}{server}, 'MyWebServer';
	}
	$http->flush;
	$checkidx->("http_127.0.0.1_8089_two\t$url\n");
}

{
	my $http = HTTP_Tiny_FileCache->new( cache_path=>$cachedir,
		urltransform => 'urlfn', verbose => $verbose, log_requests => $verbose );
	my ($url, $content ) = ("$BASE/3/a/foo",'MyWebServer/3/a/foo');
	my ($url2,$content2) = ("$BASE/3/b/foo",'MyWebServer/3/b/foo');
	{
		my $r = $http->get($url);
		ok $r->{success};
		is $r->{status}, 200;
		is $r->{content}, $content;
		ok !exists $r->{cachefile};
		is $r->{headers}{server}, 'MyWebServer';
	}
	{
		my $r = $http->get($url);
		ok $r->{success};
		is $r->{status}, 304;
		is $r->{content}, $content;
		is $r->{cachefile}, catfile($cachedir, 'foo');
		is $r->{headers}{server}, 'MyWebServer';
	}
	{
		like exception { $http->get($url2) },
			qr/\bIndex collision on "foo"/;
	}
	$http->flush;
	my $http2 = HTTP_Tiny_FileCache->new( cache_path=>$cachedir,
		urltransform => 'urlfn', nonfatal_collision=>1,
		verbose => $verbose, log_requests => $verbose );
	for (1..2) {
		my $r;
		my @w = warns { $r = $http2->get($url2) };
		is grep({/\bIndex collision on "foo"/} @w), 1;
		ok $r->{success};
		is $r->{status}, 200;
		is $r->{content}, $content2;
		ok !exists $r->{cachefile};
		is $r->{headers}{server}, 'MyWebServer';
	}
	$checkidx->("foo\t$url\n");
}

{
	open my $fh, '<', $serverlog or die "$serverlog: $!";
	my $data = do { local $/=undef; <$fh> };
	close $fh;
	is $data, join('', map {"$_\n"}
			"/one\t200", "/one\t304", "/one\t200",
			"/two\t200", "/two\t304",
			"/3/a/foo\t200", "/3/a/foo\t304", "/3/b/foo\t200", "/3/b/foo\t200",
		), 'server log is correct';
}

done_testing;
