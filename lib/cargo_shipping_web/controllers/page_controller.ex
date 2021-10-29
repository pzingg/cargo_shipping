defmodule CargoShippingWeb.PageController do
  use CargoShippingWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def clerks(conn, _params) do
    render(conn, "clerks.html")
  end

  def managers(conn, _params) do
    render(conn, "managers.html")
  end
end
