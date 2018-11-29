defmodule TdIe.ErrorConstantsSupport do
  @moduledoc false

  @ingest_support_errors %{
    existing_ingest: %{code: "EI001", name: "ingest.error.existing.ingest"}
  }

  def ingest_support_errors, do: @ingest_support_errors
end
