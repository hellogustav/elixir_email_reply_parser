defmodule ElixirEmailReplyParser.Fragment do
  @moduledoc false

  defstruct [
    signature: false,
    headers: false,
    hidden: false,
    quoted: false,
    content: nil,
    lines: []
  ]
end
