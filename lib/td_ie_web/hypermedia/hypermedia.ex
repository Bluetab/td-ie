defmodule TdIeWeb.Hypermedia do
  @moduledoc false
  def controller do
    quote do
      import TdIeWeb.Hypermedia.HypermediaControllerHelper
    end
  end

  def view do
    quote do
      import TdIeWeb.Hypermedia.HypermediaViewHelper
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
