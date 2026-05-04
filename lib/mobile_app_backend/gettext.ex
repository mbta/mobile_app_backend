defmodule MobileAppBackend.Gettext do
  defmodule Plural do
    def nplurals(:ht) do
      nplurals(:fr)
    end

    use Cldr.Gettext.Plural, cldr_backend: MobileAppBackend.Cldr
  end

  use Gettext.Backend,
    otp_app: :mobile_app_backend
end
