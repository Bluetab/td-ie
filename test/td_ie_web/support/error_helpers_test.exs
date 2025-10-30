defmodule TdIeWeb.ErrorHelpersTest do
  use ExUnit.Case

  alias TdIeWeb.ErrorHelpers

  describe "translate_error/1" do
    test "translates error message with single placeholder" do
      error = {"User %{name} not found", [name: "John"]}

      result = ErrorHelpers.translate_error(error)

      assert result == "User John not found"
    end

    test "translates error message with multiple placeholders" do
      error =
        {"%{field} %{action} failed for %{resource}",
         [field: "email", action: "validation", resource: "user"]}

      result = ErrorHelpers.translate_error(error)

      assert result == "email validation failed for user"
    end

    test "handles error without placeholders" do
      error = {"Simple error message", []}

      result = ErrorHelpers.translate_error(error)

      assert result == "Simple error message"
    end

    test "handles error with empty opts" do
      error = {"Message with %{placeholder}", []}

      result = ErrorHelpers.translate_error(error)

      assert result == "Message with %{placeholder}"
    end

    test "handles error with numeric values" do
      error = {"Error code %{code}: %{message}", [code: 404, message: "Not found"]}

      result = ErrorHelpers.translate_error(error)

      assert result == "Error code 404: Not found"
    end

    test "handles error with atom values" do
      error = {"Status: %{status}", [status: :error]}

      result = ErrorHelpers.translate_error(error)

      assert result == "Status: error"
    end

    test "handles error with boolean values" do
      error = {"Validation %{result}", [result: true]}

      result = ErrorHelpers.translate_error(error)

      assert result == "Validation true"
    end

    test "handles error with nil values" do
      error = {"Value: %{value}", [value: nil]}

      result = ErrorHelpers.translate_error(error)

      assert result == "Value: "
    end

    test "handles multiple occurrences of same placeholder" do
      error = {"%{word} %{word} %{word}", [word: "test"]}

      result = ErrorHelpers.translate_error(error)

      assert result == "test test test"
    end

    test "handles complex error message" do
      error = {
        "Failed to %{action} %{resource} '%{name}' in %{location}",
        [action: "create", resource: "user", name: "john@example.com", location: "database"]
      }

      result = ErrorHelpers.translate_error(error)

      assert result == "Failed to create user 'john@example.com' in database"
    end
  end
end
