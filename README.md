# "dispki: One-Shot Disposable PKI"

This tool helps create a disposable PKI you can used for testing purposes.
It generates a chain of X.509 RSA certificates, up to a self signed certificate.
Server certificate CN and SANs can be specified.

# Usage

    ./dispki.pl [-d|--depth <number>] [-b|--bits <number>] [-t|--ttl <number>] <server CN> [<server SANs>]

    -d| --depth <number> -> number of intermediate CAs (default is none)
    -b| --bits <number> -> key length in bits (for all key pairs, default is 2048)
    -t| --ttl <number>  -> TTL in days for all certificates (default is 365)

# Dependencies

- perl
- openssl
