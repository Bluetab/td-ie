defmodule TdIeWeb.SessionViewTest do
  use TdIeWeb.ConnCase

  alias TdIeWeb.SessionView

  describe "render/2" do
    test "renders show.json with token" do
      token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"

      result = SessionView.render("show.json", %{token: token})

      assert result == %{token: token}
    end

    test "handles empty token" do
      token = ""

      result = SessionView.render("show.json", %{token: token})

      assert result == %{token: ""}
    end

    test "handles nil token" do
      token = nil

      result = SessionView.render("show.json", %{token: token})

      assert result == %{token: nil}
    end

    test "handles complex token" do
      token =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"

      result = SessionView.render("show.json", %{token: token})

      assert result == %{token: token}
    end
  end
end
