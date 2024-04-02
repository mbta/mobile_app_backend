defmodule MobileAppBackend.Factory do
  import Test.Support.Sigils

  use ExMachina

  def alert_factory do
    %MBTAV3API.Alert{
      id: Uniq.UUID.uuid7(),
      active_period: [
        %MBTAV3API.Alert.ActivePeriod{
          start: ~B[2024-02-14T05:22:00],
          end: ~B[2024-02-14T12:34:41]
        }
      ],
      effect: :delay,
      informed_entity: [
        %MBTAV3API.Alert.InformedEntity{
          activities: [:board, :exit, :ride],
          route: "66",
          route_type: :bus
        }
      ],
      lifecycle: :new
    }
  end

  def prediction_factory do
    %MBTAV3API.Prediction{
      id: Uniq.UUID.uuid7(),
      arrival_time: nil,
      departure_time: ~B[2024-03-20 16:41:01],
      direction_id: 0,
      revenue: true,
      schedule_relationship: :added,
      status: nil,
      stop_sequence: 20,
      route_id: "Green-D",
      stop_id: "70206",
      trip_id: "ADDED-1591593214",
      vehicle_id: "G-10270"
    }
  end

  def route_pattern_factory do
    %MBTAV3API.RoutePattern{
      id: Uniq.UUID.uuid7(),
      name: "Nubian Station - Harvard Square",
      direction_id: 0,
      sort_order: 506_600_000,
      representative_trip_id: "60168428",
      route_id: "66",
      canonical: false
    }
  end

  def route_factory do
    %MBTAV3API.Route{
      id: Uniq.UUID.uuid7(),
      long_name: "Harvard Square - Nubian Station",
      short_name: "66",
      type: :bus,
      direction_names: ["Outbound", "Inbound"],
      direction_destinations: ["Harvard Square", "Nubian Station"],
      text_color: "000000"
    }
  end

  def shape_factory do
    %MBTAV3API.Shape{
      id: Uniq.UUID.uuid7(),
      polyline:
        "injaG~qzpLAFCVK|A`Bt@\\XHLk@r@{@lA_@t@O\\??m@vAcAzB[|@Kj@Qf@Ql@Or@??S`Ac@|B[nCKnAAL??ElAG|BC`B?|CCrA??A^E`AOtBCh@Gx@MfA??APKpBEj@[pEQbBEh@c@lC??SpAQz@Ot@EXS~@i@rBu@jCER??St@Ux@o@dCm@fCg@vB??m@pCQp@h@pAh@z@Zr@??\\r@Pd@HZH`@B\\@t@@bDArC?ZBt@@l@??@RBl@Fv@Ll@HZNb@h@lAR`@Zl@tA|BJTHRCV@LBvAFpA??Bn@DdA@`BAxA?VAxB?xAFnARjC??@RGlAEXI^KXWh@ONYXURs@f@SPc@X_AAI@??kBVg@Hi@Lc@Py@\\_@P{@j@a@`@u@|@mAbBUZ??]d@KPQNc@b@m@\\]Jc@Hq@DaAEw@Cs@E??G?eAK{@SOGe@OoA_@YGkA]YCu@ByAZkBZqAZ??QDo@TKLg@|@k@hA[x@iBpDkB`E_@|@KXM\\KP??OXSj@s@nBcApC]t@k@hA_@j@s@t@GHGF??qA`Ae@^{@d@cB~@qBhA{BfAED??y@h@KD]V_@XEFw@z@cAz@_@V??UNYLMHSHMDaCjAy@\\qBh@iAVE@??iBZWDi@bJ??m@pJAr@Ap@Cp@C`AIzASi@]oAYw@??IWUu@Wy@u@_Cq@sBGS_@kAc@uA[}@k@eBc@gA????Me@_AcDs@cCUeBq@mCkBiHoBkHEUWLyAt@SH??YLs@`@IFm@v@SZmAbBq@|@o@z@??IL]d@aApAOVy@fA}@`Am@b@_@NWF??KBa@Am@I_@K]KOKWQa@[_@e@[]_@m@[g@??iDeFmAmB{BiDYc@Y[CGu@_AgAkAkAgAk@m@WU??w@w@iD}Cg@c@q@i@m@g@}@u@qB_BaCmBoAcAUQ}AgASO??QMiByAUQ{@w@wBaBw@a@Sk@a@a@g@WMIOGg@IOCu@UiBY????}@Oc@?g@F]Re@v@i@lA@NDPLRDF`Bm@t@[`@K"
    }
  end

  def stop_factory do
    %MBTAV3API.Stop{
      id: Uniq.UUID.uuid7(),
      name: "Harvard Sq @ Garden St - Dawes Island",
      latitude: 42.375302,
      longitude: -71.119237,
      location_type: :stop
    }
  end

  def trip_factory do
    %MBTAV3API.Trip{
      id: Uniq.UUID.uuid7(),
      headsign: "Harvard via Allston"
    }
  end

  def vehicle_factory do
    %MBTAV3API.Vehicle{
      id: Uniq.UUID.uuid7(),
      current_status: :in_transit_to,
      stop_id: "7670",
      trip_id: "60169926"
    }
  end
end
