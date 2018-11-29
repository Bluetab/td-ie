defmodule TdIeWeb.IngestFilterView do
  use TdIeWeb, :view

  def render("show.json", %{filters: filters}) do
    %{data: filters}
  end
end
