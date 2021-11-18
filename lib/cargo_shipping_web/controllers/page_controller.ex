defmodule CargoShippingWeb.PageController do
  use CargoShippingWeb, :controller

  import CargoShippingWeb.UserAuth, only: [log_out_user: 1]

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def logout(conn, _params) do
    conn
    |> put_flash(:info, "You have been logged out.")
    |> log_out_user()
    |> halt()
  end

  def clerks(conn, _params) do
    render(conn, "clerks.html")
  end

  def managers(conn, _params) do
    render(conn, "managers.html")
  end
end
