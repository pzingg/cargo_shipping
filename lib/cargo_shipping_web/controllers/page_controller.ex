defmodule CargoShippingWeb.PageController do
  use CargoShippingWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
