# dispki: One-Shot Disposable PKI

This tool helps create a disposable PKI you can use for testing purposes, simply.

It generates a chain of X.509 certificates, up to a self-signed one.

RSA is used by default, EC is also supported.

Server certificate CN and SANs can be specified, along with various optional
parameters.

# Usage

    ./dispki.pl [-d|--depth <number>] [-b|--bits <number>] [-t|--ttl <number>] <server CN> [<server SANs>]
    ./dispki.pl [-d|--depth <number>] [-e|--ec] [-c|--curve <curve>] [-t|--ttl <number>] <server CN> [<server SANs>]

    -d| --depth <number> -> number of intermediate CAs (default is none)
    -b| --bits <number> -> key length in bits (for all key pairs, default is 2048)
    -t| --ttl <number>  -> TTL in days for all certificates (default is 365)
    -e| --ec -> switch to elliptic curve cryptosystem
    -c| --curve -> specify elliptic curve to use (default: P-256)


# Examples

## Simple CN

    ./dispki.pl bla.lu

This command creates a server certificate for CN `bla.lu`. `*.bla.lu` is
automatically added to the list of SANs.

Six files are produced:

    0_rootca_1734329560.cnf
    0_rootca_1734329560.crt
    0_rootca_1734329560.key
    0_rootca_1734329560.req
    1_server_1734329560.cnf
    1_server_1734329560.crt
    1_server_1734329560.key
    1_server_1734329560.req

These are organized as a sequence. In this case a chain was built with only 2
certificates. Root certificate has the lower index, 0.  The leaf server
certificate has index 1.

All files that belong to the same chain are suffixed by a common number that
corresponds to the time (epoch format) when the chain was generated.

`.req` are certificate requests.

`.cnf` are OpenSSL's requests configuration files that could be reused for
manual adjustments later on.

`.crt` & `.key` files are certificates and private keys, respectively.

Private keys files are not encrypted.

## CN + SAN + Intermediate certificates

    ./dispki.pl -e -d 2 bla.lu bli.lu

Compared to previous command, this one adds `bli.lu` and `*.bli.lu` to the
list of SANs of the leaf server certificate.

In this case the chain was built with 2 additional intermediate certificates
placed between leaf server certificate and self-signed root certificate.  Root
certificate has the lower index, 0.  Intermediated certificate are indexed as 1
& 2. The leaf server certificate is indexed as 3.

    0_rootca_1734300199.cnf
    0_rootca_1734300199.crt
    0_rootca_1734300199.key
    0_rootca_1734300199.req
    1_intca_1734300199.cnf
    1_intca_1734300199.crt
    1_intca_1734300199.key
    1_intca_1734300199.req
    2_intca_1734300199.cnf
    2_intca_1734300199.crt
    2_intca_1734300199.key
    2_intca_1734300199.req
    3_server_1734300199.cnf
    3_server_1734300199.crt
    3_server_1734300199.key
    3_server_1734300199.req

All keypairs are EC based (because of `-e`).

## Using the certificates

A bundle file containing all CA certificates along with a file containing
useful environment variables are created during the generation process:

    ca_bundle_1734300199
    env_1734300199

The env file can then be sourced in current shell in order to declare the
following environment variables:

    rootca_cert
    server_cert
    server_key
    ca_bundle

These variables can, for instance, be used to start an SSL/TLS server listening
on `localhost` port `443`:

    $ source env_1734300199
    $ sudo -E socat openssl-listen:443,reuseaddr,cert=$server_cert,key=$server_key,cafile=$ca_bundle,verify=0,fork STDOUT

You can connect to the server using OpenSSL's `s_client` app from another shell:

    $ source env_1734300199
    $ openssl s_client -servername bla.lu -connect localhost:443 -verifyCAfile $rootca_cert

## Clean up

`./clean.sh` will delete all generated files.

# Dependencies

- Perl
- OpenSSL version 3+
