# "dispki: One-Shot Disposable PKI"

This tool helps create a disposable PKI you can used for testing purposes.

It generates a chain of X.509 RSA certificates, up to a self-signed one.

Server certificate CN and SANs can be specified, along with various optional
parameters.

# Usage

    ./dispki.pl [-d|--depth <number>] [-b|--bits <number>] [-t|--ttl <number>] <server CN> [<server SANs>]

    -d| --depth <number> -> number of intermediate CAs (default is none)
    -b| --bits <number> -> key length in bits (for all key pairs, default is 2048)
    -t| --ttl <number>  -> TTL in days for all certificates (default is 365)

# Examples

    ./dispki.pl bla.lu

This command creates a server certificate for CN `bla.lu`. `www.bla.lu` is
automatically added to the list of SANs.

    ./dispki.pl -d 2 bla.lu bli.lu

Compared to previous command, this one adds `bli.lu` to list of SANs of the
leaf server certificate. Also, 2 intermediate certificates are placed between
leaf server certificate and self-signed root certificate.

# Dependencies

- perl
- openssl
