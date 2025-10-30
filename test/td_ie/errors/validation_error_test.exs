defmodule ValidationErrorTest do
  use ExUnit.Case

  alias ValidationError

  describe "exception struct" do
    test "creates exception with default values" do
      exception = %ValidationError{}

      assert exception.field == ""
      assert exception.error == ""
      assert exception.message == ""
    end

    test "creates exception with custom values" do
      exception = %ValidationError{
        field: "email",
        error: "invalid_format",
        message: "Email format is invalid"
      }

      assert exception.field == "email"
      assert exception.error == "invalid_format"
      assert exception.message == "Email format is invalid"
    end

    test "exception can be raised and caught" do
      exception = %ValidationError{
        field: "name",
        error: "required",
        message: "Name is required"
      }

      assert_raise ValidationError, fn ->
        raise exception
      end
    end

    test "exception message can be customized" do
      exception = %ValidationError{
        field: "age",
        error: "invalid_range",
        message: "Age must be between 18 and 100"
      }

      try do
        raise exception
      rescue
        ValidationError -> :ok
      end
    end

    test "exception with partial values" do
      exception = %ValidationError{field: "password"}

      assert exception.field == "password"
      assert exception.error == ""
      assert exception.message == ""
    end
  end
end
