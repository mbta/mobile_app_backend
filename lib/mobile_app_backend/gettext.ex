defmodule MobileAppBackend.Gettext do
  use Gettext.Backend, otp_app: :mobile_app_backend,
  priv: "priv/gettext/backend"
end
