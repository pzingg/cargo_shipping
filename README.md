# CargoShipping

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix

# Web interface

Original Java templates at `dddsample/src/main/resources/templates`


## Clerk web interface at /tracking

* `live "/", CargoLive.Search, :index` (from track.html)

## Admin web interface at /managers

* `live "/", CargoLive.Index, :index` (from admin/list.html)
* `live "/:id", CargoLive.Show, :show` (from admin/show.html)
* `live "/events", HandlingEventLive.Index, :index` (from admin/list.html)
* `live "/events/:id", HandlingEventLive.Show, :show` (from admin/show.html)

## Admin web interface TODO at /managers

* `live "/new", CargoLive.Index, :new` (from admin/registrationForm.html)
* `live "/:id/edit_destination", CargoLive.Show, :edit_destination` (from admin/pickNewDestination.html)
* `live "/:id/edit_route", CargoLive.Show, :edit_route` (from admin/selectItinerary.html)
