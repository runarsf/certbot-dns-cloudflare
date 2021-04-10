# certbot-dns-cloudflare
A Docker image to automatically retrieve wildcard certificates from Let's Encrypt using DNS-challenges.

## Getting started
Copy the contents of [docker-compose.yml](./docker-compose.yml), replace `image` with the newest version from [runarsf/certbot-dns-cloudflare/packages](https://github.com/runarsf/certbot-dns-cloudflare/packages) (`docker.pkg.github.com/runarsf/certbot-dns-cloudflare/certbot-dns-cloudflare:1.0.0`), and remove `build`.\
Required environment variables:\ 
Either set these in the `.env`-file or directory in `docker-compose.yml`.\ 
See [docker-compose.yml](./docker-compose.yml) for more variables.
  - `DOMAIN`: A comma-separated list of domains, excluding protocol and wildcard.
  - `EMAIL`: The email provided to certbot.
  - `CLOUDFLARE_TOKEN`: Create a token [profile/API Tokens](https://dash.cloudflare.com/profile/api-tokens) with `Zone:Edit`, `SSL and Certificates:Edit`, `DNS:Edit` permissions.

Does not currently support email/api-key-authentication, as it is considered deprecated.
