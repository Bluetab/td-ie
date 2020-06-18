defmodule TdIe.Accounts.User do
  @moduledoc false

  @derive Jason.Encoder
  defstruct id: 0,
            user_name: nil,
            is_admin: false,
            email: nil,
            full_name: nil,
            groups: [],
            jti: nil
end
