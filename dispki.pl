#!/usr/bin/env perl

##
## Copyright (c) 2024-2025 William Robinet <willi@mrobi.net>
##
## Permission to use, copy, modify, and distribute this software for any
## purpose with or without fee is hereby granted, provided that the above
## copyright notice and this permission notice appear in all copies.
##
## THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
## WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
## MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
## ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
## WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
## ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
## OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
##

use strict;
use warnings;
use Carp;
use Getopt::Long;

# Path to the openssl binary
my $openssl = `which openssl`;
chomp($openssl);
####

my $depth = 0;
my $bits = 2048;
my $curve = 'P-256';
my $ec = 0;
my $ttl = 365;
my $cn = "";
my $sans;
my $id = time;
my $level = 0;
my $prevca = '';

sub check_openssl_version {
    open(my $fh, "-|", "$openssl version")
        or croak "Error checking OpenSSL version!";

	croak "Wrong OpenSSL version!" if <$fh> !~ /^OpenSSL 3/;
}

sub print_usage {
    print "Usage:\n";
    print "\t$0 [-d|--depth <number>] [-b|--bits <number>] [-t|--ttl <number>] <server CN> [<server SANs>]\n\n";
    print "\t$0 [-d|--depth <number>] [-e|--ec] [-c|--curve <curve>] [-t|--ttl <number>] <server CN> [<server SANs>]\n\n";
    print "-d| --depth <number> -> number of intermediate CAs (none by default)\n";
    print "-b| --bits <number> -> key length in bits (default: 2048 bits)\n";
    print "-e| --ec -> switch to elliptic curve cryptosystem\n";
    print "-c| --curve -> specify elliptic curve to use (default: P-256)\n";
    print "-t| --ttl <number>  -> TTL in days (default: 365 days)\n";
    print "Use --help (or -h) to print this help message\n";
    exit 1;
}

my $reqCA_tpl = <<"reqCA";
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_x509
req_extensions = v3_req
prompt = no
[req_distinguished_name]
CN = "&CN&"
[v3_x509]
basicConstraints        = critical, CA:TRUE
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always, issuer:always
keyUsage                = critical, cRLSign, digitalSignature, keyCertSign
[v3_req]
basicConstraints        = critical, CA:TRUE
subjectKeyIdentifier    = hash
keyUsage                = critical, cRLSign, digitalSignature, keyCertSign
reqCA

my $req_tpl = <<"req";
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
req_extensions = v3_req
prompt = no
[req_distinguished_name]
CN = "&CN&"
[v3_req]
keyUsage = digitalSignature
extendedKeyUsage = serverAuth
subjectAltName = \@alt_names
[alt_names]
&SAN&
req

sub genroot {
    print "Generating root CA certificate & key ...\n";
    my $reqCA = $reqCA_tpl =~ s/&CN&/dispki_root_$id/r;
    my $ca = $level.'_rootca_'.$id;

    open(FH, '>', $ca.'.cnf') or die $!;
    print FH $reqCA;
    close(FH);

    my @cmd = ($openssl, 'req', '-x509', '-sha256', '-nodes', '-days', "$ttl", '-newkey');
    if($ec) {
        push(@cmd, ('ec', '-pkeyopt', "ec_paramgen_curve:$curve"))
    } else {
        push(@cmd, ("rsa:$bits"))
    }
    push(@cmd, ('-keyout', $ca.'.key', '-out', $ca.'.crt', '-config', $ca.'.cnf', '-extensions', 'v3_req'));
    system(@cmd);

    @cmd = ($openssl, 'req', '-new', '-nodes', '-sha256', '-key', $ca.'.key', '-config', $ca.'.cnf', '-reqexts', 'v3_req', '-out', $ca.'.req');
    system(@cmd);

    $prevca = $ca;
}

sub genintermediates {
    while($depth) {
        print "Generating intermediate CA certificate & key ... (level $level)\n";
        my $reqCA = $reqCA_tpl =~ s/&CN&/dispki_int_$level\_$id/r;
        my $ca = $level.'_intca_'.$id;

        open(FH, '>', $ca.'.cnf') or die $!;
        print FH $reqCA;
        close(FH);

        my @cmd = ($openssl, 'req', '-x509', '-sha256', '-nodes', '-days', "$ttl", '-newkey');
        if($ec) {
            push(@cmd, ('ec', '-pkeyopt', "ec_paramgen_curve:$curve"));
        } else {
            push(@cmd, ("rsa:$bits"));
        }
        push(@cmd, ('-keyout', $ca.'.key', '-out', $ca.'.crt', '-CA', $prevca.'.crt', '-CAkey', $prevca.'.key',
            '-config', $ca.'.cnf', '-extensions', 'v3_req'));
        system(@cmd);

        @cmd = ($openssl, 'req', '-new', '-nodes', '-sha256', '-key', $ca.'.key', '-config', $ca.'.cnf', '-reqexts', 'v3_req', '-out', $ca.'.req');
        system(@cmd);

        $prevca = $ca;
        $depth--;
        $level++;
    }
}

sub genserver {
    print "Generating server certificate & key ...\n";

    my $sanstr = "DNS.1 = $cn\nDNS.2 = *.$cn\n";

    my $i = 3;
    foreach (@{$sans}) {
        $sanstr .= "DNS.$i = $_\n";
        $i++;
        $sanstr .= "DNS.$i = *.$_\n";
        $i++;
    }

    my $req = $req_tpl =~ s/&CN&/$cn/r;
    $req = $req =~ s/&SAN&/$sanstr/r;
    my $cert = $level.'_server_'.$id;

    open(FH, '>', $cert.'.cnf') or die $!;
    print FH $req;
    close(FH);

    my @cmd = ($openssl, 'req', '-x509', '-sha256', '-nodes', '-days', "$ttl", '-newkey');
    if($ec) {
        push(@cmd, ('ec', '-pkeyopt', "ec_paramgen_curve:$curve"));
    } else {
        push(@cmd, ("rsa:$bits"));
    }
    push(@cmd, ('-keyout', $cert.'.key', '-out', $cert.'.crt', '-CA', $prevca.'.crt', '-CAkey', $prevca.'.key',
        '-config', $cert.'.cnf', '-extensions', 'v3_req'));
    system(@cmd);

	@cmd = ($openssl, 'req', '-new', '-nodes', '-sha256', '-key', $cert.'.key', '-config', $cert.'.cnf', '-reqexts', 'v3_req', '-out', $cert.'.req');
    system(@cmd);
}

sub genbundle {
    my @certs = glob("*ca_$id.crt");
    open BUNDLE, ">> ca_bundle_$id" or die $!;
    foreach(@certs){
        open CERT, "< $_" or die $!;
        print BUNDLE <CERT>;
        close CERT
    }
    close BUNDLE;
}

sub genenv {
    open ENV, "> env_$id" or die $!;
    print ENV 'export server_cert='.$level.'_server_'.$id.".crt\n";
    print ENV 'export server_key='.$level.'_server_'.$id.".key\n";
    print ENV "export rootca_cert=0_rootca_$id.crt\n";
    print ENV "export ca_bundle=ca_bundle_$id\n";
    close ENV;
}

GetOptions(
    'help|h' => sub { print_usage },
    'depth|d=i' => \$depth,
    'bits|b=i' => \$bits,
    'ec|e' => sub { $ec = 1 },
    'curve|c=s' => \$curve,
    'ttl|t=i' => \$ttl,
) or do { print_usage };

$cn = shift @ARGV;
$sans = \@ARGV;

do { print "Missing CN !\n\n"; print_usage } if not $cn;

print "Session id: $id\n";
print "CN: $cn\n";
print "SANs: $cn *.$cn";
foreach (@{$sans}) {
    print " $_ *.$_";
}
print "\nChain depth: $depth\n";
print "TTL: $ttl\n";
print "RSA modulus length: $bits\n" unless $ec;
print "EC curve: $curve\n" if $ec;

check_openssl_version;
genroot;
$level=1;
genintermediates if $depth;
genserver;
genbundle;
genenv;
