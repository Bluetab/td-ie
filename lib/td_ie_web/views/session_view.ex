defmodule TdIeWeb.SessionView do
  use TdIeWeb, :view

  def render("show.json", %{token: token}) do
    %{token: token}
  end
end
