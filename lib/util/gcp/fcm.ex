defmodule Util.GCP.FCM do
  @moduledoc """
  Wrappers for the [Firebase Cloud Messaging API][api].

  [api]: https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages
  """

  defmodule Notification do
    @moduledoc """
    https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages#notification
    """
    @type t :: %__MODULE__{title: String.t(), body: String.t()}
    @derive Jason.Encoder
    defstruct [:title, :body]
  end

  defmodule AndroidNotification do
    @moduledoc """
    https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages#androidnotification
    """
    @type visibility :: :visibility_unspecified | :private | :public | :secret
    @type t :: %__MODULE__{
            sound: String.t() | nil,
            tag: String.t() | nil,
            visibility: visibility() | nil
          }
    @derive Jason.Encoder
    defstruct [:sound, :tag, :visibility]
  end

  defmodule AndroidConfig do
    @moduledoc """
    https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages#androidconfig
    """
    @type t :: %__MODULE__{notification: AndroidNotification.t() | nil}
    @derive Jason.Encoder
    defstruct [:notification]
  end

  defmodule ApnsConfig do
    @moduledoc """
    https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages#apnsconfig
    """
    @type t :: %__MODULE__{payload: map() | nil}
    @derive Jason.Encoder
    defstruct [:payload]
  end

  defmodule FcmOptions do
    @moduledoc """
    https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages#fcmoptions
    """
    @type t :: %__MODULE__{analytics_label: String.t() | nil}
    @derive Jason.Encoder
    defstruct [:analytics_label]
  end

  defmodule Message do
    @moduledoc """
    https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages#resource:-message
    """
    @type t :: %__MODULE__{
            data: %{String.t() => String.t()} | nil,
            notification: Notification.t() | nil,
            android: AndroidConfig.t() | nil,
            apns: ApnsConfig.t() | nil,
            fcm_options: FcmOptions.t() | nil,
            token: String.t() | nil,
            fid: String.t() | nil
          }
    @derive Jason.Encoder
    defstruct [:data, :notification, :android, :apns, :fcm_options, :token, :fid]
  end

  @doc "https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages/send"
  @spec send(String.t(), String.t(), %{
          optional(:validate_only) => boolean() | nil,
          message: Message.t()
        }) ::
          {:ok, Req.Response.t()} | {:error, Exception.t()}
  def send(token, parent, body) do
    Util.GCP.base_req()
    |> Req.post(
      base_url: "https://fcm.googleapis.com",
      auth: {:bearer, token},
      url: "/v1/#{parent}/messages:send",
      json: body
    )
  end
end
