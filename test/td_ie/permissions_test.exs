defmodule TdIe.PermissionsTest do
  use TdIeWeb.ConnCase

  alias TdIe.Permissions

  describe "Permissions.get_search_permissions/1" do
    @tag authentication: [role: "admin"]
    test "returns a map with values :all for admin role", %{claims: claims} do
      assert Permissions.get_search_permissions(claims) == %{
               "view_approval_pending_ingests" => :all,
               "view_deprecated_ingests" => :all,
               "view_draft_ingests" => :all,
               "view_published_ingests" => :all,
               "view_rejected_ingests" => :all,
               "view_versioned_ingests" => :all
             }
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "returns a map with :none values for regular users", %{claims: claims} do
      assert Permissions.get_search_permissions(claims) == %{
               "view_approval_pending_ingests" => :none,
               "view_deprecated_ingests" => :none,
               "view_draft_ingests" => :none,
               "view_published_ingests" => :none,
               "view_rejected_ingests" => :none,
               "view_versioned_ingests" => :none
             }
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "includes :all values for default permissions", %{claims: claims} do
      CacheHelpers.put_default_permissions(["view_published_ingests", "foo"])

      assert Permissions.get_search_permissions(claims) == %{
               "view_approval_pending_ingests" => :none,
               "view_deprecated_ingests" => :none,
               "view_draft_ingests" => :none,
               "view_published_ingests" => :all,
               "view_rejected_ingests" => :none,
               "view_versioned_ingests" => :none
             }
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "includes domain_id values for session permissions, excepting defaults", %{
      claims: claims
    } do
      CacheHelpers.put_default_permissions(["view_published_ingests", "foo"])
      %{id: id1} = CacheHelpers.put_domain()
      %{id: id2} = CacheHelpers.put_domain(parent_id: id1)
      %{id: id3} = CacheHelpers.put_domain()

      put_session_permissions(claims, %{
        "view_rejected_ingests" => [id2],
        "view_published_ingests" => [id3],
        "view_deprecated_ingests" => [id3]
      })

      assert Permissions.get_search_permissions(claims) == %{
               "view_approval_pending_ingests" => :none,
               "view_deprecated_ingests" => [id3],
               "view_draft_ingests" => :none,
               "view_published_ingests" => :all,
               "view_rejected_ingests" => [id2],
               "view_versioned_ingests" => :none
             }
    end
  end
end
