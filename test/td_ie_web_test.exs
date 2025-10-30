defmodule TdIeWebTest do
  use ExUnit.Case

  alias TdIeWeb

  describe "controller/0" do
    test "returns quoted expression for controller" do
      result = TdIeWeb.controller()

      assert is_tuple(result)
      assert elem(result, 0) == :__block__
    end
  end

  describe "view/0" do
    test "returns quoted expression for view" do
      result = TdIeWeb.view()

      assert is_tuple(result)
      assert elem(result, 0) == :__block__
    end
  end

  describe "router/0" do
    test "returns quoted expression for router" do
      result = TdIeWeb.router()

      assert is_tuple(result)
      assert elem(result, 0) == :__block__
    end
  end

  describe "channel/0" do
    test "returns quoted expression for channel" do
      result = TdIeWeb.channel()

      assert is_tuple(result)
      assert elem(result, 0) == :use
    end
  end

  describe "module functions" do
    test "module can be loaded" do
      assert Code.ensure_loaded?(TdIeWeb)
    end

    test "has __using__ macro" do
      assert macro_exported?(TdIeWeb, :__using__, 1)
    end
  end
end
