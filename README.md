# TdIe

## Environment variables

### SSL conection

- DB_SSL: boolean value, to enable TSL config, by default is false.
- DB_SSL_CACERTFILE: path of the certification authority cert file "/path/to/ca.crt", required when DB_SSL is true.
- DB_SSL_VERSION: available versions are tlsv1.2, tlsv1.3 by default is tlsv1.2.

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.create && mix ecto.migrate`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4014`](http://localhost:4014) from your browser.

Ready to run in production? Please [check our deployment guides](http://www.phoenixframework.org/docs/deployment).

### Elastic bulk page size configuration
- BULK_PAGE_SIZE_INGESTS: default 1000


## Learn more

  * Official website: http://www.phoenixframework.org/
  * Guides: http://phoenixframework.org/docs/overview
  * Docs: https://hexdocs.pm/phoenix
  * Mailing list: http://groups.google.com/group/phoenix-talk
  * Source: https://github.com/phoenixframework/phoenix
