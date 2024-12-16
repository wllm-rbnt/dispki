# dispki: One-Shot Disposable PKI

This tool helps create a disposable PKI you can used for testing purposes, simply.

It generates a chain of X.509 RSA certificates, up to a self-signed one.

Server certificate CN and SANs can be specified, along with various optional
parameters.

# Usage

    ./dispki.pl [-d|--depth <number>] [-b|--bits <number>] [-t|--ttl <number>] <server CN> [<server SANs>]

    -d| --depth <number> -> number of intermediate CAs (default is none)
    -b| --bits <number> -> key length in bits (for all key pairs, default is 2048)
    -t| --ttl <number>  -> TTL in days for all certificates (default is 365)

# Examples

## Simple CN

    ./dispki.pl bla.lu

This command creates a server certificate for CN `bla.lu`. `www.bla.lu` is
automatically added to the list of SANs.

Six files are produced:

    0_rootca_1734329560.crt
    0_rootca_1734329560.key
    0_rootca_1734329560.req
    1_server_1734329560.crt
    1_server_1734329560.key
    1_server_1734329560.req

These are organized as a sequence. In this case a chain was built with only 2
certificates. Root certificate has the lower index, 0.  The leaf server
certificate has indexed 1.

All files that belong to the same chain are suffixed by a common number that
corresponds to the time (epoch format) when the chain was generated.

`.req` are OpenSSL's configurations that could be reused for manual adjustments
later on.

`.crt` & `.key` files are certificates and keys, respectively.

## CN + SAN + Intermediate certificates

    ./dispki.pl -d 2 bla.lu bli.lu

Compared to previous command, this one adds `bli.lu` and `www.bli.lu` to the
list of SANs of the leaf server certificate.

In this case the chain was built with 2 additional intermediate certificates
placed between leaf server certificate and self-signed root certificate.  Root
certificate has the lower index, 0.  Intermediated certificate are indexed as 1
& 2. The leaf server certificate is indexed as 3.

    0_rootca_1734300199.crt
    0_rootca_1734300199.key
    0_rootca_1734300199.req
    1_intca_1734300199.crt
    1_intca_1734300199.key
    1_intca_1734300199.req
    2_intca_1734300199.crt
    2_intca_1734300199.key
    2_intca_1734300199.req
    3_server_1734300199.crt
    3_server_1734300199.key
    3_server_1734300199.req

# Dependencies

- perl
- openssl
