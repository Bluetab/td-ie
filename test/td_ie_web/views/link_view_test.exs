defmodule TdIeWeb.LinkViewTest do
  use TdIeWeb.ConnCase

  alias TdIeWeb.LinkView

  describe "render/2" do
    test "renders embedded.json with link only" do
      link = %{id: "1", source: "ingest:123"}
      assigns = %{link: link}

      result = LinkView.render("embedded.json", assigns)

      assert is_map(result)
    end

    test "renders link.json with link" do
      link = %{id: "1", source: "ingest:123", target: "ingest:456"}

      result = LinkView.render("link.json", %{link: link})

      assert result == link
    end

    test "handles complex link data" do
      link = %{
        id: "123",
        source: "ingest:456",
        target: "ingest:789",
        metadata: %{created_at: "2023-01-01", type: "reference"}
      }

      result = LinkView.render("link.json", %{link: link})

      assert result == link
    end

    test "handles empty link" do
      link = %{}

      result = LinkView.render("link.json", %{link: link})

      assert result == %{}
    end

    test "module can be loaded" do
      assert Code.ensure_loaded?(TdIeWeb.LinkView)
    end
  end
end
