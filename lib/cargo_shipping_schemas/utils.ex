defmodule CargoShippingSchemas.Utils do
  @moduledoc """
  A sub-boundary for the database ID generators.
  """

  def get_temp_id() do
    :crypto.strong_rand_bytes(5) |> Base.url_encode64() |> binary_part(0, 5)
  end
end
