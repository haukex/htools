#!perl
package HTTP_Tiny_FileCache;
use warnings;
use strict;
use Carp;
use Data::Dumper; sub pp;
use Hash::Util qw/lock_keys lock_hashref/;
use File::Spec::Functions qw/ catdir tmpdir catfile /;
use File::Path qw/make_path/;
use IO::Socket::SSL 1.56 ();
use Net::SSLeay 1.49 ();
use HTTP::Tiny ();

=head1 SYNOPSIS

 use HTTP_Tiny_FileCache;
 my $http = HTTP_Tiny_FileCache->new(  # default options:
 	http_tiny          => HTTP::Tiny->new(),
 	http_tiny_opts     => {},  # don't use with http_tiny
 	log_requests       => 0,   # log only actual HTTP requests
 	cache_path         => '/tmp/HTTP_Tiny_FileCache',
 	default_mode       => CACHE_MIRROR,
 	urltransform       => 'sha256',
 	nonfatal_collision => 0,
 	verbose            => 0,
 );
 my $response = $http->get($url, CACHE_ALWAYS);  # mode is optional
 # $response is a HTTP::Tiny response hashref
 # $response->{cachefile} is set if the cache file was used
 # $response->{headers} will not exist if no HTTP request was sent
 # ->get() will die unless $response->{succcess}!

Cache Modes:
C<CACHE_NEVER> to always do a new GET request;
C<CACHE_MIRROR> to do a GET with If-Modified-Since when applicable;
C<CACHE_ALWAYS> to not touch the server at all if a file exists locally.

URL Transforms (mapping URLs to filenames):
C<sha256> takes a SHA-256 (in hex) of the URL (requires L<Digest::SHA|Digest::SHA>);
C<clean> applies L<Text::CleanFragment|Text::CleanFragment> to the URL;
C<urlfn> takes the final pathname component of the URL or C<die>s if there is none (requires L<URI|URI>).

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

use Exporter 'import';
use constant CACHE_NEVER  => 0;  ## no critic (ProhibitConstantPragma)
use constant CACHE_MIRROR => 1;  ## no critic (ProhibitConstantPragma)
use constant CACHE_ALWAYS => 2;  ## no critic (ProhibitConstantPragma)
our @EXPORT = qw/ CACHE_NEVER CACHE_MIRROR CACHE_ALWAYS /;  ## no critic (ProhibitAutomaticExportation)

our $DEFAULT_CACHE_PATH = catdir(tmpdir, __PACKAGE__);
our $INDEX_FILE_NAME = '.cacheindex';

my %transforms = (
	sha256 => sub {
		require Digest::SHA;
		return Digest::SHA::sha256_hex("$_[0]");
	},
	clean => sub {
		require Text::CleanFragment;
		return Text::CleanFragment::clean_fragment("$_[0]");
	},
	urlfn => sub {
		require URI;
		my $uri = URI->new("$_[0]");
		my $fn = ($uri->path_segments)[-1];
		( $fn = $uri->host_port )=~s/[\w\.\-]+/_/g unless length $fn;
		die "Error: failed to resolve filename for URL ".pp("$_[0]") unless length $fn;
		return $fn;
	},
);

my %NEW_KNOWN_ARGS = map {$_=>1} qw/ http_tiny http_tiny_opts log_requests
	cache_path default_mode urltransform nonfatal_collision verbose /;

sub new {  ## no critic (ProhibitExcessComplexity)
	my ($class,%args) = @_;
	$NEW_KNOWN_ARGS{$_} or croak "$class->new: Unknown argument ".pp($_) for keys %NEW_KNOWN_ARGS;
	lock_keys %args, keys %NEW_KNOWN_ARGS;
	carp "$class->new: Warning: http_tiny_opts has no effect when http_tiny given"
		if $args{http_tiny} && $args{http_tiny_opts};
	croak "$class->new: Bad default_mode ".pp($args{default_mode})
		if defined($args{default_mode}) && !( $args{default_mode}==CACHE_NEVER
			|| $args{default_mode}==CACHE_MIRROR || $args{default_mode}==CACHE_ALWAYS );
	my $trans = $transforms{sha256};
	if ( $args{urltransform} ) {
		if ( !ref($args{urltransform}) && exists $transforms{$args{urltransform}} )
			{ $trans = $transforms{$args{urltransform}} }
		elsif ( ref $args{urltransform} eq 'CODE' )
			{ $trans = $args{urltransform} }
		else { croak "$class->new: Bad urltransform ".pp($args{urltransform}) }
	}
	my $self = {
		http => $args{http_tiny}||HTTP::Tiny->new( %{$args{http_tiny_opts}||{}} ),
		log_requests => $args{log_requests},
		cache_path => defined($args{cache_path}) ? $args{cache_path} : $DEFAULT_CACHE_PATH,
		default_mode => defined($args{default_mode}) ? $args{default_mode} : CACHE_MIRROR,
		transform => $trans,
		nonfatal_collision => $args{nonfatal_collision},
		verbose => $args{verbose},
		index => {},
		_ => { index_dirty=>0 }, # the hash gets locked, so this is a rw sub-hash
	};
	$self->{cache_index_file} = catfile($self->{cache_path}, $INDEX_FILE_NAME);
	bless $self, $class;
	lock_hashref $self;
	make_path( $self->{cache_path}, { verbose=>$self->{verbose} } );
	print STDERR $class,"->new: cache_path is ",pp($self->{cache_path}),"\n" if $self->{verbose};
	if ( open my $fh, '<:raw:encoding(UTF-8)', $self->{cache_index_file} ) {
		local $/ = "\n";
		while (<$fh>) {
			chomp;
			if (/\A([^\t]+)\t([^\t]+)\z/) { $self->{index}{$1} = $2 }
			else { warn "Bad index line in ".pp($self->{cache_index_file}).": ".pp($_) }
		}
		close $fh;
		print STDERR $class,"->new: read index from ",pp($self->{cache_index_file}),"\n" if $self->{verbose};
	}
	return $self;
}

# Possible To-Do for Later: don't cache if $url->host eq 'localhost' || $url->host eq '127.0.0.1' ?

sub get {  ## no critic (ProhibitExcessComplexity)
	my ($self,$url,$mode) = @_;
	croak ref($self)."->get: Bad URL ".pp($url)
		if !length($url) || $url=~/[\t\n]/;
	if (defined $mode)
		{ croak ref($self)."->get: Bad mode ".pp($mode)
			unless $mode==CACHE_NEVER || $mode==CACHE_MIRROR || $mode==CACHE_ALWAYS }
	else { $mode = $self->{default_mode} }
	my $cfn = $self->{transform}->($url);
	croak ref($self)."->get: Transform of URL ".pp($url)." to bad filename ".pp($cfn)
		if !length($cfn) || $cfn=~/[\t\n\/]/;
	print STDERR ref($self),"->get: URL ",pp($url),", cache filename ",pp($cfn),"\n" if $self->{verbose};
	if ( exists $self->{index}{$cfn} ) {
		if ( $self->{index}{$cfn} ne $url && $mode!=CACHE_NEVER ) {
			my $msg = ref($self)."->get: Index collision on ".pp($cfn).": old ".pp($self->{index}{$cfn}).", new ".pp($url);
			if ( $self->{nonfatal_collision} ) {
				carp $msg;
				$mode = CACHE_NEVER; # we have to fetch this URL
			}
			else { croak $msg }
		}
	} else { $self->{index}{$cfn} = $url; $self->{_}{index_dirty} = 1 }
	my $cachefile = catfile( $self->{cache_path}, $cfn );
	if ( $mode==CACHE_ALWAYS && -e $cachefile ) {
		open my $fh, '<:raw', $cachefile or croak "Couldn't read ".pp($cachefile).": $!";
		my $data = do { local $/=undef; <$fh> };
		close $fh;
		print STDERR ref($self),"->get: read cached file for ",pp($url),"\n" if $self->{verbose};
		return { success => 1, url => $url,  # a fake HTTP::Tiny hashref
			status => 200, reason => '(from cache)', content => $data,
			cachefile => $cachefile };
	}
	my $resp;
	if ( $mode==CACHE_NEVER ) {
		print $url, ": " if $self->{log_requests};
		$resp = $self->{http}->get($url);
		confess "Unexpected key cachefile" if exists $resp->{cachefile};
	}
	else {
		print $url, ": " if $self->{log_requests};
		$resp = $self->{http}->mirror($url, $cachefile);
		confess "Unexpected key cachefile" if exists $resp->{cachefile};
		$resp->{cachefile} = $cachefile if $resp->{status}==304;
		open my $fh, '<:raw', $cachefile or croak "Couldn't read ".pp($cachefile).": $!";
		$resp->{content} = do { local $/=undef; <$fh> };
		close $fh;
	}
	my $status = $resp->{status}==599 ? $resp->{content} : "$resp->{status} $resp->{reason}";
	print $status, "\n" if $self->{log_requests};
	if ( $resp->{success} ) {
		print STDERR ref($self),"->get: fetched ",pp($url),": ",$status,"\n" if $self->{verbose};
		return $resp;
	}
	else { croak pp($url).": $status" }
}

sub flush {
	my ($self) = @_;
	return unless $self->{_}{index_dirty};
	if ( open my $fh, '>:raw:encoding(UTF-8)', $self->{cache_index_file} ) {
		for my $k (sort keys %{ $self->{index} }) {
			my $v = $self->{index}{$k};
			die "Tab or newline in key ".pp($k)." or value ".pp($v)
				if $k=~/[\t\n]/ || $v=~/[\t\n]/;
			print $fh $k,"\t",$v,"\n";
		}
		close $fh;
		print STDERR ref($self),"->flush: wrote index to ",pp($self->{cache_index_file}),"\n" if $self->{verbose};
		$self->{_}{index_dirty} = 0;
	}
	else { warn "Can't write to ".pp($self->{cache_index_file}).": $!" }
	return;
}

sub DESTROY {
	my $self = shift;
	$self->flush;
	return;
}

sub pp {
	confess "Bad number of args to pp" unless @_==1;
	return Data::Dumper->new([shift])->Terse(1)->Purity(1)->Useqq(1)
		->Quotekeys(0)->Sortkeys(1)->Indent(0)->Pair('=>')->Dump;
}

1;
