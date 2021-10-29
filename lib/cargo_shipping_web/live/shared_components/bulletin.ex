defmodule CargoShippingWeb.SharedComponents.Bulletin do
  @moduledoc """
  Support "toasty" messages.
  """
  use TypedStruct

  typedstruct do
    @typedoc "A bulletin"
    field :id, String.t(), enforce: true
    field :level, String.t(), enforce: true
    field :body, String.t(), enforce: true
  end
end
