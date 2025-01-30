# yet-another-https-script
Yet another script to get HTTPS for your web servers 

## Testing in progress
Please DO NOT use on production servers. Thanks. Use at your own risk.

## Purposes
  1. Obtain a DDNS subdomain
  2. Install reverse proxy (caddy)
  3. Get your website with HTTPS with just 1 single click

## Usage
```shell
curl https://raw.githubusercontent.com/SodaWithoutSparkles/yet-another-https-script/refs/heads/main/yahs.sh | bash
```

## Examples
Passing arguments to bash scripts obtained through curl can be done as so:
```shell
curl https://raw.githubusercontent.com/SodaWithoutSparkles/yet-another-https-script/refs/heads/main/yahs.sh | bash -s -- <options>
```
This is equivlent to:
```shell
./yahs.sh <options>
```
- Get HTTPS for your site at localhost:8080
  - ```shell
    ./yahs.sh -b localhost:8080
    ```
    
- Just get a DDNS domain
  - ```shell
    ./yahs.sh -q
    ```
- You already had a domain name and the correct DNS records
  - ```shell
    ./yahs.sh --backend-url localhost:8080 --domain-name example.com
    ```

## All options
```shell
Usage: ./yahs.sh [options]

Options:
  -n, --domain-name      Set the domain name for the HTTPS server
  -b, --backend-url      Set the backend URL to be reverse proxied (required, unless --no-caddy is set)
  -p, --port             Set the port number for the HTTPS server, default is 443
  -d, --debug            Enable debug mode
      --force            Ignore checks results
      --pkgs             Install packages automatically
  -v, --version[s]       Show script version
  -y, --defaults         Use default settings, but interactively ask for permission to install things
  -6, --ipv6             Enable IPv6 support
      --no-ipv4          Disable IPv4 support
      --no-ipv6          Disable IPv6 support
      --no-caddy         Disable caddy installation
  -q, --quiet            Suppress most outputs, equivalent to --defaults, --force, --pkgs, --no-caddy. Except for errors
      --no-log           Disable logging to /tmp/yahs.log
  -h, --help             Display this help message
Examples:
  ./yahs.sh --backend-url localhost:8080                                     # Minimul viable example
  ./yahs.sh --backend-url localhost:8080 --domain-name example.com --ipv6    # Provide domain name and enable IPv6
  ./yahs.sh -b localhost:8080 -n example.com --debug --defaults --pkgs       # No user interaction
  ./yahs.sh -b localhost:8080 -n example.com -dy --pkgs --force              # Ignore checks as well
  ./yahs.sh -b localhost:8080 -y --force --pkgs                              # Doesn't even need a domain
  ./yahs.sh -q                                                               # Just get a DDNS domain and exit
```
