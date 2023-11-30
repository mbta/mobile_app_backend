defmodule MobileAppBackendWeb.SchemaTest do
  use MobileAppBackendWeb.ConnCase

  import Test.Support.Helpers

  @stop_query """
  query {
    stop(id: "place-boyls") {
      id
      name
      routes {
        id
        name
        routePatterns {
          id
          name
        }
      }
    }
  }
  """

  test "query: stop", %{conn: conn} do
    bypass = bypass_api()

    Bypass.expect(bypass, "GET", "/stops/place-boyls", fn conn ->
      Phoenix.Controller.json(conn, %{
        data: %{
          attributes: %{
            address: "Boylston St and Tremont St, Boston, MA",
            description: nil,
            latitude: 42.35302,
            location_type: 1,
            longitude: -71.06459,
            municipality: "Boston",
            name: "Boylston",
            platform_code: nil,
            platform_name: nil,
            wheelchair_boarding: 2
          },
          id: "place-boyls",
          links: %{self: "/stops/place-boyls"},
          relationships: %{
            child_stops: %{
              data: [
                %{id: "70158", type: "stop"},
                %{id: "70159", type: "stop"},
                %{id: "door-boyls-inbound", type: "stop"},
                %{id: "door-boyls-outbound", type: "stop"},
                %{id: "node-boyls-in-farepaid", type: "stop"},
                %{id: "node-boyls-in-fareunpaid", type: "stop"},
                %{id: "node-boyls-instair-platform", type: "stop"},
                %{id: "node-boyls-out-farepaid", type: "stop"},
                %{id: "node-boyls-out-fareunpaid", type: "stop"},
                %{id: "node-boyls-outstair-platform", type: "stop"}
              ]
            },
            facilities: %{
              data: [
                %{id: "fvm-201221", type: "facility"},
                %{id: "fvm-201222", type: "facility"},
                %{id: "fvm-201223", type: "facility"},
                %{id: "fvm-201224", type: "facility"},
                %{id: "fvm-202157", type: "facility"}
              ],
              links: %{related: "/facilities/?filter[stop]=place-boyls"}
            },
            parent_station: %{data: nil},
            zone: %{data: nil}
          },
          type: "stop"
        },
        included: [
          %{
            attributes: %{
              address: nil,
              description: "Boylston - Green Line - Park Street & North",
              latitude: 42.352531,
              location_type: 0,
              longitude: -71.064682,
              municipality: "Boston",
              name: "Boylston",
              platform_code: nil,
              platform_name: "Park Street & North",
              wheelchair_boarding: 2
            },
            id: "70158",
            links: %{self: "/stops/70158"},
            relationships: %{
              facilities: %{links: %{related: "/facilities/?filter[stop]=70158"}},
              parent_station: %{data: %{id: "place-boyls", type: "stop"}},
              zone: %{data: %{id: "RapidTransit", type: "zone"}}
            },
            type: "stop"
          },
          %{
            attributes: %{
              address: nil,
              description: "Boylston - Green Line - Copley & West",
              latitude: 42.353214,
              location_type: 0,
              longitude: -71.064545,
              municipality: "Boston",
              name: "Boylston",
              platform_code: nil,
              platform_name: "Copley & West",
              wheelchair_boarding: 2
            },
            id: "70159",
            links: %{self: "/stops/70159"},
            relationships: %{
              facilities: %{links: %{related: "/facilities/?filter[stop]=70159"}},
              parent_station: %{data: %{id: "place-boyls", type: "stop"}},
              zone: %{data: %{id: "RapidTransit", type: "zone"}}
            },
            type: "stop"
          },
          %{
            attributes: %{
              address: nil,
              description: "Boylston - Boston Common, Street",
              latitude: 42.352531,
              location_type: 2,
              longitude: -71.064685,
              municipality: "Boston",
              name: "Boylston - Boston Common, Street",
              platform_code: nil,
              platform_name: nil,
              wheelchair_boarding: 2
            },
            id: "door-boyls-inbound",
            links: %{self: "/stops/door-boyls-inbound"},
            relationships: %{
              facilities: %{
                links: %{related: "/facilities/?filter[stop]=door-boyls-inbound"}
              },
              parent_station: %{data: %{id: "place-boyls", type: "stop"}},
              zone: %{data: nil}
            },
            type: "stop"
          },
          %{
            attributes: %{
              address: nil,
              description: "Boylston - Boston Common, Street",
              latitude: 42.353214,
              location_type: 2,
              longitude: -71.064546,
              municipality: "Boston",
              name: "Boylston - Boston Common, Street",
              platform_code: nil,
              platform_name: nil,
              wheelchair_boarding: 2
            },
            id: "door-boyls-outbound",
            links: %{self: "/stops/door-boyls-outbound"},
            relationships: %{
              facilities: %{
                links: %{related: "/facilities/?filter[stop]=door-boyls-outbound"}
              },
              parent_station: %{data: %{id: "place-boyls", type: "stop"}},
              zone: %{data: nil}
            },
            type: "stop"
          },
          %{
            attributes: %{
              latitude: nil,
              long_name: "Boylston fare vending machine 201221",
              longitude: nil,
              properties: [
                %{name: "enclosed", value: 1},
                %{name: "excludes-stop", value: "door-boyls-outbound"},
                %{name: "payment-form-accepted", value: "cash"},
                %{name: "payment-form-accepted", value: "credit-debit-card"}
              ],
              type: "FARE_VENDING_MACHINE"
            },
            id: "fvm-201221",
            links: %{self: "/facilities/fvm-201221"},
            relationships: %{
              stop: %{data: %{id: "place-boyls", type: "stop"}}
            },
            type: "facility"
          },
          %{
            attributes: %{
              latitude: nil,
              long_name: "Boylston fare vending machine 201222",
              longitude: nil,
              properties: [
                %{name: "enclosed", value: 1},
                %{name: "excludes-stop", value: "door-boyls-outbound"},
                %{name: "payment-form-accepted", value: "cash"},
                %{name: "payment-form-accepted", value: "credit-debit-card"}
              ],
              type: "FARE_VENDING_MACHINE"
            },
            id: "fvm-201222",
            links: %{self: "/facilities/fvm-201222"},
            relationships: %{
              stop: %{data: %{id: "place-boyls", type: "stop"}}
            },
            type: "facility"
          },
          %{
            attributes: %{
              latitude: nil,
              long_name: "Boylston fare vending machine 201223",
              longitude: nil,
              properties: [
                %{name: "enclosed", value: 1},
                %{name: "excludes-stop", value: "door-boyls-inbound"},
                %{name: "payment-form-accepted", value: "cash"},
                %{name: "payment-form-accepted", value: "credit-debit-card"}
              ],
              type: "FARE_VENDING_MACHINE"
            },
            id: "fvm-201223",
            links: %{self: "/facilities/fvm-201223"},
            relationships: %{
              stop: %{data: %{id: "place-boyls", type: "stop"}}
            },
            type: "facility"
          },
          %{
            attributes: %{
              latitude: nil,
              long_name: "Boylston fare vending machine 201224",
              longitude: nil,
              properties: [
                %{name: "enclosed", value: 1},
                %{name: "excludes-stop", value: "door-boyls-inbound"},
                %{name: "payment-form-accepted", value: "cash"},
                %{name: "payment-form-accepted", value: "credit-debit-card"}
              ],
              type: "FARE_VENDING_MACHINE"
            },
            id: "fvm-201224",
            links: %{self: "/facilities/fvm-201224"},
            relationships: %{
              stop: %{data: %{id: "place-boyls", type: "stop"}}
            },
            type: "facility"
          },
          %{
            attributes: %{
              latitude: nil,
              long_name: "Boylston fare vending machine 202157",
              longitude: nil,
              properties: [
                %{name: "enclosed", value: 1},
                %{name: "excludes-stop", value: "door-boyls-inbound"},
                %{name: "payment-form-accepted", value: "credit-debit-card"}
              ],
              type: "FARE_VENDING_MACHINE"
            },
            id: "fvm-202157",
            links: %{self: "/facilities/fvm-202157"},
            relationships: %{
              stop: %{data: %{id: "place-boyls", type: "stop"}}
            },
            type: "facility"
          },
          %{
            attributes: %{
              address: nil,
              description: "Boylston - Paid side of fare gates",
              latitude: nil,
              location_type: 3,
              longitude: nil,
              municipality: "Boston",
              name: "Boylston",
              platform_code: nil,
              platform_name: nil,
              wheelchair_boarding: 1
            },
            id: "node-boyls-in-farepaid",
            links: %{self: "/stops/node-boyls-in-farepaid"},
            relationships: %{
              facilities: %{
                links: %{related: "/facilities/?filter[stop]=node-boyls-in-farepaid"}
              },
              parent_station: %{data: %{id: "place-boyls", type: "stop"}},
              zone: %{data: nil}
            },
            type: "stop"
          },
          %{
            attributes: %{
              address: nil,
              description: "Boylston - Unpaid side of fare gates",
              latitude: nil,
              location_type: 3,
              longitude: nil,
              municipality: "Boston",
              name: "Boylston",
              platform_code: nil,
              platform_name: nil,
              wheelchair_boarding: 1
            },
            id: "node-boyls-in-fareunpaid",
            links: %{self: "/stops/node-boyls-in-fareunpaid"},
            relationships: %{
              facilities: %{
                links: %{related: "/facilities/?filter[stop]=node-boyls-in-fareunpaid"}
              },
              parent_station: %{data: %{id: "place-boyls", type: "stop"}},
              zone: %{data: nil}
            },
            type: "stop"
          },
          %{
            attributes: %{
              address: nil,
              description: "Boylston - Bottom of Park Street & East stairs",
              latitude: nil,
              location_type: 3,
              longitude: nil,
              municipality: "Boston",
              name: "Boylston",
              platform_code: nil,
              platform_name: nil,
              wheelchair_boarding: 1
            },
            id: "node-boyls-instair-platform",
            links: %{self: "/stops/node-boyls-instair-platform"},
            relationships: %{
              facilities: %{
                links: %{related: "/facilities/?filter[stop]=node-boyls-instair-platform"}
              },
              parent_station: %{data: %{id: "place-boyls", type: "stop"}},
              zone: %{data: nil}
            },
            type: "stop"
          },
          %{
            attributes: %{
              address: nil,
              description: "Boylston - Paid side of fare gates",
              latitude: nil,
              location_type: 3,
              longitude: nil,
              municipality: "Boston",
              name: "Boylston",
              platform_code: nil,
              platform_name: nil,
              wheelchair_boarding: 1
            },
            id: "node-boyls-out-farepaid",
            links: %{self: "/stops/node-boyls-out-farepaid"},
            relationships: %{
              facilities: %{
                links: %{related: "/facilities/?filter[stop]=node-boyls-out-farepaid"}
              },
              parent_station: %{data: %{id: "place-boyls", type: "stop"}},
              zone: %{data: nil}
            },
            type: "stop"
          },
          %{
            attributes: %{
              address: nil,
              description: "Boylston - Unpaid side of fare gates",
              latitude: nil,
              location_type: 3,
              longitude: nil,
              municipality: "Boston",
              name: "Boylston",
              platform_code: nil,
              platform_name: nil,
              wheelchair_boarding: 1
            },
            id: "node-boyls-out-fareunpaid",
            links: %{self: "/stops/node-boyls-out-fareunpaid"},
            relationships: %{
              facilities: %{
                links: %{related: "/facilities/?filter[stop]=node-boyls-out-fareunpaid"}
              },
              parent_station: %{data: %{id: "place-boyls", type: "stop"}},
              zone: %{data: nil}
            },
            type: "stop"
          },
          %{
            attributes: %{
              address: nil,
              description: "Boylston - Bottom of Copley & West stairs",
              latitude: nil,
              location_type: 3,
              longitude: nil,
              municipality: "Boston",
              name: "Boylston",
              platform_code: nil,
              platform_name: nil,
              wheelchair_boarding: 1
            },
            id: "node-boyls-outstair-platform",
            links: %{self: "/stops/node-boyls-outstair-platform"},
            relationships: %{
              facilities: %{
                links: %{
                  related: "/facilities/?filter[stop]=node-boyls-outstair-platform"
                }
              },
              parent_station: %{data: %{id: "place-boyls", type: "stop"}},
              zone: %{data: nil}
            },
            type: "stop"
          }
        ],
        jsonapi: %{version: "1.0"}
      })
    end)

    Bypass.expect(bypass, "GET", "/routes/", fn conn ->
      Phoenix.Controller.json(conn, %{
        data: [
          %{
            attributes: %{
              color: "00843D",
              description: "Rapid Transit",
              direction_destinations: ["Boston College", "Government Center"],
              direction_names: ["West", "East"],
              fare_class: "Rapid Transit",
              long_name: "Green Line B",
              short_name: "B",
              sort_order: 10_032,
              text_color: "FFFFFF",
              type: 0
            },
            id: "Green-B",
            links: %{self: "/routes/Green-B"},
            relationships: %{
              line: %{data: %{id: "line-Green", type: "line"}},
              route_patterns: %{
                data: [
                  %{id: "Green-B-812-0", type: "route_pattern"},
                  %{id: "Green-B-812-0_70202_170137_2", type: "route_pattern"},
                  %{id: "Green-B-812-1", type: "route_pattern"},
                  %{id: "Green-B-812-1_170136_70201_0", type: "route_pattern"},
                  %{id: "Green-B-816-0", type: "route_pattern"},
                  %{id: "Green-B-816-0_70202_170137_0_70206_70202_0", type: "route_pattern"},
                  %{id: "Green-B-816-0_70202_170137_2", type: "route_pattern"},
                  %{id: "Green-B-816-1", type: "route_pattern"},
                  %{id: "Green-B-816-1_170136_70201_0", type: "route_pattern"},
                  %{id: "Green-B-816-1_170136_70201_2_70201_70205_2", type: "route_pattern"}
                ]
              }
            },
            type: "route"
          },
          %{
            attributes: %{
              color: "00843D",
              description: "Rapid Transit",
              direction_destinations: ["Cleveland Circle", "Government Center"],
              direction_names: ["West", "East"],
              fare_class: "Rapid Transit",
              long_name: "Green Line C",
              short_name: "C",
              sort_order: 10_033,
              text_color: "FFFFFF",
              type: 0
            },
            id: "Green-C",
            links: %{self: "/routes/Green-C"},
            relationships: %{
              line: %{data: %{id: "line-Green", type: "line"}},
              route_patterns: %{
                data: [
                  %{id: "Green-C-832-0", type: "route_pattern"},
                  %{id: "Green-C-832-0_70202_70151_2", type: "route_pattern"},
                  %{id: "Green-C-832-1", type: "route_pattern"},
                  %{id: "Green-C-832-1_70150_70201_0", type: "route_pattern"},
                  %{id: "Green-C-836-0", type: "route_pattern"},
                  %{id: "Green-C-836-0_70206_70202_0", type: "route_pattern"},
                  %{id: "Green-C-836-0_70206_70202_2_70202_70151_2", type: "route_pattern"},
                  %{id: "Green-C-836-1", type: "route_pattern"},
                  %{id: "Green-C-836-1_70201_70205_0_70150_70201_0", type: "route_pattern"},
                  %{id: "Green-C-836-1_70201_70205_2", type: "route_pattern"}
                ]
              }
            },
            type: "route"
          },
          %{
            attributes: %{
              color: "00843D",
              description: "Rapid Transit",
              direction_destinations: ["Riverside", "Union Square"],
              direction_names: ["West", "East"],
              fare_class: "Rapid Transit",
              long_name: "Green Line D",
              short_name: "D",
              sort_order: 10_034,
              text_color: "FFFFFF",
              type: 0
            },
            id: "Green-D",
            links: %{self: "/routes/Green-D"},
            relationships: %{
              line: %{data: %{id: "line-Green", type: "line"}},
              route_patterns: %{
                data: [
                  %{id: "Green-D-855-0", type: "route_pattern"},
                  %{id: "Green-D-855-0_70206_70202_0", type: "route_pattern"},
                  %{id: "Green-D-855-0_70206_70202_2_70202_70151_2", type: "route_pattern"},
                  %{id: "Green-D-855-0_70504_70206_2", type: "route_pattern"},
                  %{
                    id: "Green-D-855-0_70504_70206_2_70206_70202_2_70202_70151_2",
                    type: "route_pattern"
                  },
                  %{id: "Green-D-855-1", type: "route_pattern"},
                  %{id: "Green-D-855-1_70201_70205_0_70150_70201_0", type: "route_pattern"},
                  %{id: "Green-D-855-1_70201_70205_2", type: "route_pattern"},
                  %{id: "Green-D-855-1_70205_70503_0", type: "route_pattern"},
                  %{
                    id: "Green-D-855-1_70205_70503_0_70201_70205_0_70150_70201_0",
                    type: "route_pattern"
                  },
                  %{id: "Green-D-856-0", type: "route_pattern"},
                  %{id: "Green-D-856-0_70206_70202_0", type: "route_pattern"},
                  %{id: "Green-D-856-0_70206_70202_2_70202_70151_2", type: "route_pattern"},
                  %{id: "Green-D-856-1", type: "route_pattern"},
                  %{id: "Green-D-856-1_70201_70205_0_70150_70201_0", type: "route_pattern"},
                  %{id: "Green-D-856-1_70201_70205_2", type: "route_pattern"}
                ]
              }
            },
            type: "route"
          },
          %{
            attributes: %{
              color: "00843D",
              description: "Rapid Transit",
              direction_destinations: ["Heath Street", "Medford/Tufts"],
              direction_names: ["West", "East"],
              fare_class: "Rapid Transit",
              long_name: "Green Line E",
              short_name: "E",
              sort_order: 10_035,
              text_color: "FFFFFF",
              type: 0
            },
            id: "Green-E",
            links: %{self: "/routes/Green-E"},
            relationships: %{
              line: %{data: %{id: "line-Green", type: "line"}},
              route_patterns: %{
                data: [
                  %{id: "Green-E-86-1", type: "route_pattern"},
                  %{id: "Green-E-886-0", type: "route_pattern"},
                  %{id: "Green-E-886-0_70206_70260_0", type: "route_pattern"},
                  %{id: "Green-E-886-0_70512_70206_2", type: "route_pattern"},
                  %{id: "Green-E-886-1", type: "route_pattern"},
                  %{id: "Green-E-886-1_70205_70511_0", type: "route_pattern"},
                  %{id: "Green-E-886-1_70260_70205_2", type: "route_pattern"}
                ]
              }
            },
            type: "route"
          }
        ],
        included: [
          %{
            attributes: %{
              canonical: false,
              direction_id: 0,
              name: "Babcock Street - Boston College",
              sort_order: 100_320_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-B-812-0_70202_170137_2",
            links: %{self: "/route_patterns/Green-B-812-0_70202_170137_2"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58397501-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD2",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-B", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 1,
              name: "Cleveland Circle - Kenmore",
              sort_order: 100_331_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-C-832-1_70150_70201_0",
            links: %{self: "/route_patterns/Green-C-832-1_70150_70201_0"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58397576-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD0",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-C", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 0,
              name: "Medford/Tufts - North Station",
              sort_order: 100_340_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-D-856-0_70206_70202_0",
            links: %{self: "/route_patterns/Green-D-856-0_70206_70202_0"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58398269-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD0",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-D", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: true,
              direction_id: 0,
              name: "Government Center - Boston College",
              sort_order: 100_320_000,
              time_desc: nil,
              typicality: 1
            },
            id: "Green-B-812-0",
            links: %{self: "/route_patterns/Green-B-812-0"},
            relationships: %{
              representative_trip: %{data: %{id: "canonical-Green-B-C1-0", type: "trip"}},
              route: %{data: %{id: "Green-B", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 0,
              name: "Kenmore - Cleveland Circle",
              sort_order: 100_330_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-C-836-0_70206_70202_2_70202_70151_2",
            links: %{self: "/route_patterns/Green-C-836-0_70206_70202_2_70202_70151_2"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58397581-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD22",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-C", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: true,
              direction_id: 0,
              name: "Medford/Tufts - Heath Street",
              sort_order: 100_350_000,
              time_desc: nil,
              typicality: 1
            },
            id: "Green-E-886-0",
            links: %{self: "/route_patterns/Green-E-886-0"},
            relationships: %{
              representative_trip: %{data: %{id: "canonical-Green-E-C1-0", type: "trip"}},
              route: %{data: %{id: "Green-E", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 1,
              name: "Riverside - North Station",
              sort_order: 100_341_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-D-855-1_70205_70503_0",
            links: %{self: "/route_patterns/Green-D-855-1_70205_70503_0"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id: "58398331-20:30-HayGLHayGLHayGLHayGLNorthMedfordNorthUnionSuspendD0",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-D", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 0,
              name: "Medford/Tufts - North Station",
              sort_order: 100_320_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-B-816-0_70202_170137_0_70206_70202_0",
            links: %{self: "/route_patterns/Green-B-816-0_70202_170137_0_70206_70202_0"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58397599-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD00",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-B", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: true,
              direction_id: 0,
              name: "Government Center - Cleveland Circle",
              sort_order: 100_330_000,
              time_desc: nil,
              typicality: 1
            },
            id: "Green-C-832-0",
            links: %{self: "/route_patterns/Green-C-832-0"},
            relationships: %{
              representative_trip: %{data: %{id: "canonical-Green-C-C1-0", type: "trip"}},
              route: %{data: %{id: "Green-C", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 1,
              name: "North Station - Medford/Tufts",
              sort_order: 100_331_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-C-836-1_70201_70205_2",
            links: %{self: "/route_patterns/Green-C-836-1_70201_70205_2"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58397582-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD2",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-C", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 1,
              name: "Riverside - Kenmore",
              sort_order: 100_341_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-D-856-1_70201_70205_0_70150_70201_0",
            links: %{self: "/route_patterns/Green-D-856-1_70201_70205_0_70150_70201_0"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58398268-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD00",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-D", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 0,
              name: "Medford/Tufts - North Station",
              sort_order: 100_330_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-C-836-0_70206_70202_0",
            links: %{self: "/route_patterns/Green-C-836-0_70206_70202_0"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58397581-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD0",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-C", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 1,
              name: "East Somerville - Medford/Tufts",
              sort_order: 100_351_040,
              time_desc: nil,
              typicality: 3
            },
            id: "Green-E-86-1",
            links: %{self: "/route_patterns/Green-E-86-1"},
            relationships: %{
              representative_trip: %{data: %{id: "58485809", type: "trip"}},
              route: %{data: %{id: "Green-E", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 0,
              name: "Babcock Street - Boston College",
              sort_order: 100_320_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-B-816-0_70202_170137_2",
            links: %{self: "/route_patterns/Green-B-816-0_70202_170137_2"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58397599-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD2",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-B", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 1,
              name: "Boston College - Babcock Street",
              sort_order: 100_321_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-B-816-1_170136_70201_0",
            links: %{self: "/route_patterns/Green-B-816-1_170136_70201_0"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58397508-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD0",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-B", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: true,
              direction_id: 1,
              name: "Heath Street - Medford/Tufts",
              sort_order: 100_351_000,
              time_desc: nil,
              typicality: 1
            },
            id: "Green-E-886-1",
            links: %{self: "/route_patterns/Green-E-886-1"},
            relationships: %{
              representative_trip: %{data: %{id: "canonical-Green-E-C1-1", type: "trip"}},
              route: %{data: %{id: "Green-E", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: true,
              direction_id: 1,
              name: "Boston College - Government Center",
              sort_order: 100_321_000,
              time_desc: nil,
              typicality: 1
            },
            id: "Green-B-812-1",
            links: %{self: "/route_patterns/Green-B-812-1"},
            relationships: %{
              representative_trip: %{data: %{id: "canonical-Green-B-C1-1", type: "trip"}},
              route: %{data: %{id: "Green-B", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 1,
              name: "North Station - Medford/Tufts",
              sort_order: 100_341_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-D-856-1_70201_70205_2",
            links: %{self: "/route_patterns/Green-D-856-1_70201_70205_2"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58398268-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD2",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-D", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 0,
              name: "Medford/Tufts - Cleveland Circle",
              sort_order: 100_330_040,
              time_desc: "Mornings only",
              typicality: 3
            },
            id: "Green-C-836-0",
            links: %{self: "/route_patterns/Green-C-836-0"},
            relationships: %{
              representative_trip: %{data: %{id: "58485660", type: "trip"}},
              route: %{data: %{id: "Green-C", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 0,
              name: "North Station - Heath Street",
              sort_order: 100_350_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-E-886-0_70512_70206_2",
            links: %{self: "/route_patterns/Green-E-886-0_70512_70206_2"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id: "58397680-20:30-HayGLHayGLHayGLHayGLNorthMedfordNorthUnionSuspendD2",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-E", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 0,
              name: "North Station - Riverside",
              sort_order: 100_340_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-D-855-0_70504_70206_2",
            links: %{self: "/route_patterns/Green-D-855-0_70504_70206_2"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id: "58398315-20:30-HayGLHayGLHayGLHayGLNorthMedfordNorthUnionSuspendD2",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-D", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 1,
              name: "Boston College - Medford/Tufts",
              sort_order: 100_321_040,
              time_desc: "Early mornings only",
              typicality: 3
            },
            id: "Green-B-816-1",
            links: %{self: "/route_patterns/Green-B-816-1"},
            relationships: %{
              representative_trip: %{data: %{id: "58486222", type: "trip"}},
              route: %{data: %{id: "Green-B", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 0,
              name: "Kenmore - Riverside",
              sort_order: 100_340_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-D-855-0_70504_70206_2_70206_70202_2_70202_70151_2",
            links: %{
              self: "/route_patterns/Green-D-855-0_70504_70206_2_70206_70202_2_70202_70151_2"
            },
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58398315-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD222",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-D", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 0,
              name: "Union Square - North Station",
              sort_order: 100_340_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-D-855-0_70206_70202_0",
            links: %{self: "/route_patterns/Green-D-855-0_70206_70202_0"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58398254-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD0",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-D", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 1,
              name: "Heath Street - North Station",
              sort_order: 100_351_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-E-886-1_70205_70511_0",
            links: %{self: "/route_patterns/Green-E-886-1_70205_70511_0"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id: "58397671-20:30-HayGLHayGLHayGLHayGLNorthMedfordNorthUnionSuspendD0",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-E", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 1,
              name: "Riverside - Kenmore",
              sort_order: 100_341_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-D-855-1_70205_70503_0_70201_70205_0_70150_70201_0",
            links: %{
              self: "/route_patterns/Green-D-855-1_70205_70503_0_70201_70205_0_70150_70201_0"
            },
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58398331-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD000",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-D", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 1,
              name: "North Station - Union Square",
              sort_order: 100_341_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-D-855-1_70201_70205_2",
            links: %{self: "/route_patterns/Green-D-855-1_70201_70205_2"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58398253-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD2",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-D", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 0,
              name: "Medford/Tufts - North Station",
              sort_order: 100_350_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-E-886-0_70206_70260_0",
            links: %{self: "/route_patterns/Green-E-886-0_70206_70260_0"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58397672-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD0",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-E", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 0,
              name: "Kenmore - Cleveland Circle",
              sort_order: 100_330_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-C-832-0_70202_70151_2",
            links: %{self: "/route_patterns/Green-C-832-0_70202_70151_2"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58397575-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD2",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-C", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 1,
              name: "Cleveland Circle - Medford/Tufts",
              sort_order: 100_331_040,
              time_desc: "Early mornings only",
              typicality: 3
            },
            id: "Green-C-836-1",
            links: %{self: "/route_patterns/Green-C-836-1"},
            relationships: %{
              representative_trip: %{data: %{id: "58485669", type: "trip"}},
              route: %{data: %{id: "Green-C", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 1,
              name: "North Station - Medford/Tufts",
              sort_order: 100_321_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-B-816-1_170136_70201_2_70201_70205_2",
            links: %{self: "/route_patterns/Green-B-816-1_170136_70201_2_70201_70205_2"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58397508-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD22",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-B", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 1,
              name: "North Station - Medford/Tufts",
              sort_order: 100_351_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-E-886-1_70260_70205_2",
            links: %{self: "/route_patterns/Green-E-886-1_70260_70205_2"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58397597-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD2",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-E", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 0,
              name: "Medford/Tufts - Boston College",
              sort_order: 100_320_040,
              time_desc: "Mornings only",
              typicality: 3
            },
            id: "Green-B-816-0",
            links: %{self: "/route_patterns/Green-B-816-0"},
            relationships: %{
              representative_trip: %{data: %{id: "58486194", type: "trip"}},
              route: %{data: %{id: "Green-B", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: true,
              direction_id: 1,
              name: "Riverside - Union Square",
              sort_order: 100_341_000,
              time_desc: nil,
              typicality: 1
            },
            id: "Green-D-855-1",
            links: %{self: "/route_patterns/Green-D-855-1"},
            relationships: %{
              representative_trip: %{data: %{id: "canonical-Green-D-C1-1", type: "trip"}},
              route: %{data: %{id: "Green-D", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 1,
              name: "Riverside - Medford/Tufts",
              sort_order: 100_341_040,
              time_desc: "Weekday early mornings only",
              typicality: 3
            },
            id: "Green-D-856-1",
            links: %{self: "/route_patterns/Green-D-856-1"},
            relationships: %{
              representative_trip: %{data: %{id: "58398268", type: "trip"}},
              route: %{data: %{id: "Green-D", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 1,
              name: "Boston College - Babcock Street",
              sort_order: 100_321_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-B-812-1_170136_70201_0",
            links: %{self: "/route_patterns/Green-B-812-1_170136_70201_0"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58397500-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD0",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-B", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 0,
              name: "Kenmore - Riverside",
              sort_order: 100_340_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-D-855-0_70206_70202_2_70202_70151_2",
            links: %{self: "/route_patterns/Green-D-855-0_70206_70202_2_70202_70151_2"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58398254-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD22",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-D", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 0,
              name: "Kenmore - Riverside",
              sort_order: 100_340_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-D-856-0_70206_70202_2_70202_70151_2",
            links: %{self: "/route_patterns/Green-D-856-0_70206_70202_2_70202_70151_2"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58398269-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD22",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-D", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 1,
              name: "Riverside - Kenmore",
              sort_order: 100_341_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-D-855-1_70201_70205_0_70150_70201_0",
            links: %{self: "/route_patterns/Green-D-855-1_70201_70205_0_70150_70201_0"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58398253-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD00",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-D", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: true,
              direction_id: 1,
              name: "Cleveland Circle - Government Center",
              sort_order: 100_331_000,
              time_desc: nil,
              typicality: 1
            },
            id: "Green-C-832-1",
            links: %{self: "/route_patterns/Green-C-832-1"},
            relationships: %{
              representative_trip: %{data: %{id: "canonical-Green-C-C1-1", type: "trip"}},
              route: %{data: %{id: "Green-C", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 0,
              name: "Medford/Tufts - Riverside",
              sort_order: 100_340_040,
              time_desc: "Weekday mornings only",
              typicality: 3
            },
            id: "Green-D-856-0",
            links: %{self: "/route_patterns/Green-D-856-0"},
            relationships: %{
              representative_trip: %{data: %{id: "58398269", type: "trip"}},
              route: %{data: %{id: "Green-D", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: false,
              direction_id: 1,
              name: "Cleveland Circle - Kenmore",
              sort_order: 100_331_990,
              time_desc: nil,
              typicality: 4
            },
            id: "Green-C-836-1_70201_70205_0_70150_70201_0",
            links: %{self: "/route_patterns/Green-C-836-1_70201_70205_0_70150_70201_0"},
            relationships: %{
              representative_trip: %{
                data: %{
                  id:
                    "58397582-20:30-BabcockGovernmentCenterGovtCtrKenmoreCDGovtCtrNorthStaGovtCtrNorthStaHeathNorthSusNorthMedfordNorthUnionSuspendD00",
                  type: "trip"
                }
              },
              route: %{data: %{id: "Green-C", type: "route"}}
            },
            type: "route_pattern"
          },
          %{
            attributes: %{
              canonical: true,
              direction_id: 0,
              name: "Union Square - Riverside",
              sort_order: 100_340_000,
              time_desc: nil,
              typicality: 1
            },
            id: "Green-D-855-0",
            links: %{self: "/route_patterns/Green-D-855-0"},
            relationships: %{
              representative_trip: %{data: %{id: "canonical-Green-D-C1-0", type: "trip"}},
              route: %{data: %{id: "Green-D", type: "route"}}
            },
            type: "route_pattern"
          }
        ],
        jsonapi: %{version: "1.0"}
      })
    end)

    conn =
      post(conn, "/graphql", %{
        "query" => @stop_query
      })

    assert %{"data" => %{"stop" => stop_data}} = json_response(conn, 200)
    assert %{"id" => "place-boyls", "name" => "Boylston", "routes" => routes} = stop_data

    routes = Enum.sort_by(routes, & &1["id"])

    assert routes |> Enum.map(& &1["id"]) == [
             "Green-B",
             "Green-C",
             "Green-D",
             "Green-E"
           ]

    assert %{
             "id" => "Green-B",
             "name" => "Green Line B",
             "routePatterns" => route_patterns
           } = hd(routes)

    assert length(route_patterns) > 0
  end
end
