defmodule MobileAppBackend.Notifications.NotificationTitle do
  alias MBTAV3API.Line
  alias MBTAV3API.Route
  alias Util.PolymorphicJson

  defmodule BareLabel do
    @type t :: %__MODULE__{label: String.t()}
    @derive PolymorphicJson
    defstruct [:label]
  end

  defmodule ModeLabel do
    @type t :: %__MODULE__{label: String.t(), mode: Route.type()}
    @derive PolymorphicJson
    defstruct [:label, :mode]
  end

  defmodule MultipleRoutes do
    @type t :: %__MODULE__{}
    @derive PolymorphicJson
    defstruct []
  end

  @type t :: BareLabel.t() | ModeLabel.t() | MultipleRoutes.t()

  @spec from_lines_or_routes([Line.t() | Route.t()]) :: t()
  def from_lines_or_routes(lines_or_routes) do
    case lines_or_routes do
      [%Route{type: :bus, short_name: name, line_id: "line-SL" <> _}] ->
        %BareLabel{label: "Silver Line #{name}"}

      [%Route{type: :bus, short_name: name}] ->
        %ModeLabel{label: name, mode: :bus}

      [%Route{type: :commuter_rail, long_name: name}] ->
        %BareLabel{label: String.replace(name, "/", " / ")}

      [%_{long_name: name, short_name: ""}] ->
        %BareLabel{label: name}

      [%_{long_name: "", short_name: name}] ->
        %BareLabel{label: name}

      [%_{long_name: name}] ->
        %BareLabel{label: name}

      _ ->
        %MultipleRoutes{}
    end
  end
end
