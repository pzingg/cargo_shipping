defmodule CargoShippingWeb.PageController do
  use CargoShippingWeb, :controller

  alias CargoShippingWeb.UserAuth

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def logout(conn, _params) do
    conn
    |> put_flash(:info, "You have been logged out.")
    |> UserAuth.log_out_user()
    |> halt()
  end

  def clerks(conn, _params) do
    render(conn, "clerks.html")
  end

  def managers(conn, _params) do
    render(conn, "managers.html")
  end
end
