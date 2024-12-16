#!/usr/bin/env perl

##
## Copyright (c) 2024 William Robinet <willi@mrobi.net>
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
    exit 1
}

my $reqCA_tpl = <<"reqCA";
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no
[req_distinguished_name]
CN = "&CN&"
[v3_req]
basicConstraints        = critical, CA:TRUE
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always, issuer:always
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

    open(FH, '>', $ca.'.req') or die $!;
    print FH $reqCA;
    close(FH);

    if($ec) {
        system($openssl, 'req', '-x509', '-sha256', '-nodes', '-days', "$ttl", '-newkey', 'ec', '-pkeyopt', "ec_paramgen_curve:$curve",
            '-keyout', $ca.'.key', '-out', $ca.'.crt', '-config', $ca.'.req', '-extensions', 'v3_req');
    } else {
        system($openssl, 'req', '-x509', '-sha256', '-nodes', '-days', "$ttl", '-newkey', "rsa:$bits",
            '-keyout', $ca.'.key', '-out', $ca.'.crt', '-config', $ca.'.req', '-extensions', 'v3_req');
    }
    $prevca = $ca;
}

sub genintermediates {
    while($depth) {
        print "Generating intermediate CA certificate & key ... (level $level)\n";
        my $reqCA = $reqCA_tpl =~ s/&CN&/dispki_int_$level\_$id/r;
        my $ca = $level.'_intca_'.$id;

        open(FH, '>', $ca.'.req') or die $!;
        print FH $reqCA;
        close(FH);

        if($ec) {
            system($openssl, 'req', '-x509', '-sha256', '-nodes', '-days', "$ttl", '-newkey', 'ec', '-pkeyopt', "ec_paramgen_curve:$curve",
                '-keyout', $ca.'.key', '-out', $ca.'.crt', '-CA', $prevca.'.crt', '-CAkey', $prevca.'.key',
                '-config', $ca.'.req', '-extensions', 'v3_req');
        } else {
            system($openssl, 'req', '-x509', '-sha256', '-nodes', '-days', "$ttl", '-newkey', "rsa:$bits",
                '-keyout', $ca.'.key', '-out', $ca.'.crt', '-CA', $prevca.'.crt', '-CAkey', $prevca.'.key',
                '-config', $ca.'.req', '-extensions', 'v3_req');
        }
        $prevca = $ca;
        $depth--;
        $level++;
    }
}

sub genserver {
    print "Generating server certificate & key ...\n";

    my $sanstr = "DNS.1 = $cn\nDNS.2 = www.$cn\n";

    my $i = 3;
    foreach (@{$sans}) {
        $sanstr .= "DNS.$i = $_\n";
        $i++;
        $sanstr .= "DNS.$i = www.$_\n";
        $i++;
    }

    my $req = $req_tpl =~ s/&CN&/$cn/r;
    $req = $req =~ s/&SAN&/$sanstr/r;
    my $cert = $level.'_server_'.$id;

    open(FH, '>', $cert.'.req') or die $!;
    print FH $req;
    close(FH);

    if($ec) {
        system($openssl, 'req', '-x509', '-sha256', '-nodes', '-days', "$ttl", '-newkey', 'ec', '-pkeyopt', "ec_paramgen_curve:$curve",
            '-keyout', $cert.'.key', '-out', $cert.'.crt', '-CA', $prevca.'.crt', '-CAkey', $prevca.'.key',
            '-config', $cert.'.req', '-extensions', 'v3_req');
    } else {
        system($openssl, 'req', '-x509', '-sha256', '-nodes', '-days', "$ttl", '-newkey', "rsa:$bits",
            '-keyout', $cert.'.key', '-out', $cert.'.crt', '-CA', $prevca.'.crt', '-CAkey', $prevca.'.key',
            '-config', $cert.'.req', '-extensions', 'v3_req');
    }
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

print "CN: ".$cn."\n";
print "SANs: www.$cn";
foreach (@{$sans}) {
    print " $_ www.$_";
}
print "\nChain depth: ".$depth."\n";
print "TTL: ".$ttl."\n";
print "RSA modulus length: ".$bits."\n" unless $ec;
print "EC curve: ".$curve."\n" if $ec;

genroot;
$level=1;
genintermediates if $depth;
genserver;
