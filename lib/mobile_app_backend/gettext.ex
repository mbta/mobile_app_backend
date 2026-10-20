defmodule MobileAppBackend.Gettext do
  defmodule Plural do
    def nplurals(:ht) do
      nplurals(:fr)
    end

    use Cldr.Gettext.Plural, cldr_backend: MobileAppBackend.Cldr
  end

  use Gettext.Backend,
    otp_app: :mobile_app_backend

  defmodule Macros do
    @doc """
    Gets text and specifies a comment.

    ## Examples

        iex> import #{__MODULE__}
        iex> quote do
        ...>   gettext("Hello, %{audience}",
        ...>     comment: "Greeting common in programming",
        ...>     audience: "world"
        ...>   )
        ...> end
        ...> |> Macro.expand_once(__ENV__)
        ...> |> Macro.to_string()
        ...> |> then(&(&1 <> "\\n"))
        \"\"\"
        Gettext.Macros.gettext_comment("Greeting common in programming")
        Gettext.Macros.gettext("Hello, %{audience}", audience: "world")
        \"\"\"

        iex> import #{__MODULE__}
        iex> quote do
        ...>   gettext("Message with no comment", comment: nil)
        ...> end
        ...> |> Macro.expand_once(__ENV__)
        ...> |> Macro.to_string()
        ...> |> then(&(&1 <> "\\n"))
        \"\"\"
        Gettext.Macros.gettext("Message with no comment")
        \"\"\"

        iex> import #{__MODULE__}
        iex> quote do
        ...>   gettext("Multiple comments", comment: ["Comment 1", "Comment 2"])
        ...> end
        ...> |> Macro.expand_once(__ENV__)
        ...> |> Macro.to_string()
        ...> |> then(&(&1 <> "\\n"))
        \"\"\"
        Gettext.Macros.gettext_comment("Comment 1")
        Gettext.Macros.gettext_comment("Comment 2")
        Gettext.Macros.gettext("Multiple comments")
        \"\"\"

        iex> import #{__MODULE__}
        iex> quote do
        ...>   gettext("Forgot the comment")
        ...> end
        ...> |> Macro.expand_once(__ENV__)
        ** (KeyError) key :comment not found in:
        ...

        iex> import #{__MODULE__}
        iex> quote do
        ...>   gettext("Has a %{comment} binding",
        ...>     comment: "A failure that won’t happen but would be annoying to diagnose"
        ...>   )
        ...> end
        ...> |> Macro.expand_once(__ENV__)
        ** (RuntimeError) %{comment} interpolation doesn’t work in this macro, rename the binding
    """
    defmacro gettext(msgid, opts \\ []) do
      if String.contains?(msgid, "%{comment}") do
        raise "%{comment} interpolation doesn’t work in this macro, rename the binding"
      end

      {comment, bindings} = Keyword.pop!(opts, :comment)

      comment_calls =
        comment
        |> List.wrap()
        |> Enum.map(
          &quote do
            Gettext.Macros.gettext_comment(unquote(&1))
          end
        )

      real_gettext_args = if bindings != [], do: [msgid, bindings], else: [msgid]

      quote do
        unquote_splicing(comment_calls)
        Gettext.Macros.gettext(unquote_splicing(real_gettext_args))
      end
    end
  end

  defmacro __using__(_) do
    Module.put_attribute(__CALLER__.module, :__gettext_backend__, __MODULE__)

    quote do
      require Gettext.Macros
      import MobileAppBackend.Gettext.Macros
    end
  end
end
