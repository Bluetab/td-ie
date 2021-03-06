defmodule TdIe.IngestRichTextTest do
  @moduledoc """
  Rich text test
  """
  use TdIe.DataCase
  alias TdIe.Ingests.RichText

  describe "ingests_rich_text" do
    test "to_rich_text/1 nil input" do
      assert RichText.to_rich_text(nil) == %{}
    end

    test "to_rich_text/1 empty input" do
      assert RichText.to_rich_text("") == %{}
    end

    test "to_rich_text/1 not empty input" do
      input = "Hola\nMundo"

      assert RichText.to_rich_text(input) == %{
               "document" => %{
                 "nodes" => [
                   %{
                     "nodes" => [%{"leaves" => [%{"text" => "Hola"}], "object" => "text"}],
                     "object" => "block",
                     "type" => "paragraph"
                   },
                   %{
                     "nodes" => [%{"leaves" => [%{"text" => "Mundo"}], "object" => "text"}],
                     "object" => "block",
                     "type" => "paragraph"
                   }
                 ]
               }
             }
    end

    test "to_plain_text/1 nil input" do
      assert RichText.to_plain_text(nil) == ""
    end

    test "to_plain_text/1 empty input" do
      assert RichText.to_plain_text("") == ""
    end

    test "to_plain_text/1 not empty input" do
      input = %{
        "document" => %{
          "nodes" => [
            %{
              "nodes" => [%{"leaves" => [%{"text" => "Hola"}], "object" => "text"}],
              "object" => "block",
              "type" => "paragraph"
            },
            %{
              "nodes" => [%{"leaves" => [%{"text" => "Mundo"}], "object" => "text"}],
              "object" => "block",
              "type" => "paragraph"
            }
          ]
        }
      }

      assert RichText.to_plain_text(input) == "Hola Mundo"
    end
  end
end
