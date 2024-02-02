defmodule Test.Support.Sigils do
  @doc "Like `Kernel.sigil_N/2`, but in Boston time (America/New_York)."
  defmacro sigil_B(text, modifiers) do
    quote do
      DateTime.from_naive!(sigil_N(unquote(text), unquote(modifiers)), "America/New_York")
    end
  end
end
