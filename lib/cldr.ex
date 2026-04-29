defmodule MobileAppBackend.Cldr do
  use Cldr,
    default_locale: Application.compile_env!(:mobile_app_backend, :default_locale_code),
    gettext: Application.compile_env!(:mobile_app_backend, :gettext_backend),
    json_library: Jason,
    locales: Application.compile_env!(:mobile_app_backend, :locale_codes),
    otp_app: :mobile_app_backend,
    providers: [Cldr.Calendar, Cldr.DateTime, Cldr.List, Cldr.Number, Cldr.Unit],
    precompile_number_formats: ["#,##0"]
end
