defmodule TdIe.Canada.LinkAbilitiesTest do
  use TdIe.DataCase

  alias TdIe.Auth.Claims
  alias TdIe.Canada.LinkAbilities

  describe "can?/3" do
    test "admin can create link for any resource" do
      claims = %Claims{role: "admin"}
      resource = %{ingest: "123"}

      result = LinkAbilities.can?(claims, :create_link, resource)

      assert result == true
    end

    test "admin can perform any action on Link struct" do
      claims = %Claims{role: "admin"}
      link = %TdCache.Link{id: 1, source: "ingest:123"}

      result = LinkAbilities.can?(claims, :delete, link)

      assert result == true
    end

    test "admin can perform any action on link hint" do
      claims = %Claims{role: "admin"}
      resource = %{hint: :link}

      result = LinkAbilities.can?(claims, :delete, resource)

      assert result == true
    end
  end
end
