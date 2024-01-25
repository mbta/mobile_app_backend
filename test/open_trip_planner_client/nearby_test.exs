defmodule OpenTripPlannerClient.NearbyTest do
  use ExUnit.Case, async: true

  describe "parse/1" do
    test "correctly ignores massport" do
      assert {:ok,
              [
                %MBTAV3API.Stop{id: "17091", name: "Terminal A"},
                %MBTAV3API.Stop{id: "17095", name: "Terminal E - Arrivals Level"}
              ]} =
               OpenTripPlannerClient.Nearby.parse(%{
                 "data" => %{
                   "nearest" => %{
                     "edges" => [
                       %{
                         "node" => %{
                           "distance" => 238,
                           "place" => %{
                             "gtfsId" => "2272_2274:1013",
                             "lat" => 42.366236,
                             "lon" => -71.024623,
                             "name" => "Terminal A Next Stop (BT, FH, BB)",
                             "parentStation" => nil
                           }
                         }
                       },
                       %{
                         "node" => %{
                           "distance" => 310,
                           "place" => %{
                             "gtfsId" => "2272_2274:1007",
                             "lat" => 42.365629,
                             "lon" => -71.024241,
                             "name" => "Terminal A",
                             "parentStation" => nil
                           }
                         }
                       },
                       %{
                         "node" => %{
                           "distance" => 375,
                           "place" => %{
                             "gtfsId" => "2272_2274:82",
                             "lat" => 42.365093,
                             "lon" => -71.02199,
                             "name" => "Terminal A - Arrivals",
                             "parentStation" => nil
                           }
                         }
                       },
                       %{
                         "node" => %{
                           "distance" => 378,
                           "place" => %{
                             "gtfsId" => "2272_2274:90",
                             "lat" => 42.3650612,
                             "lon" => -71.0219053,
                             "name" => "Terminal A – LEX Drop Off",
                             "parentStation" => nil
                           }
                         }
                       },
                       %{
                         "node" => %{
                           "distance" => 429,
                           "place" => %{
                             "gtfsId" => "2272_2274:55",
                             "lat" => 42.36481,
                             "lon" => -71.02139,
                             "name" => "Terminal A - Arrivals",
                             "parentStation" => nil
                           }
                         }
                       },
                       %{
                         "node" => %{
                           "distance" => 435,
                           "place" => %{
                             "gtfsId" => "2272_2274:61",
                             "lat" => 42.364905,
                             "lon" => -71.021368,
                             "name" => "Terminal A - Departures",
                             "parentStation" => nil
                           }
                         }
                       },
                       %{
                         "node" => %{
                           "distance" => 489,
                           "place" => %{
                             "gtfsId" => "mbta-ma-us:17091",
                             "lat" => 42.364612,
                             "lon" => -71.020862,
                             "name" => "Terminal A",
                             "parentStation" => nil
                           }
                         }
                       },
                       %{
                         "node" => %{
                           "distance" => 506,
                           "place" => %{
                             "gtfsId" => "2272_2274:59",
                             "lat" => 42.369236,
                             "lon" => -71.01968,
                             "name" => "Terminal E - Arrivals",
                             "parentStation" => nil
                           }
                         }
                       },
                       %{
                         "node" => %{
                           "distance" => 511,
                           "place" => %{
                             "gtfsId" => "2272_2274:1",
                             "lat" => 42.364403,
                             "lon" => -71.02055,
                             "name" => "Terminal A - Arrivals",
                             "parentStation" => nil
                           }
                         }
                       },
                       %{
                         "node" => %{
                           "distance" => 518,
                           "place" => %{
                             "gtfsId" => "2272_2274:36",
                             "lat" => 42.364646,
                             "lon" => -71.020972,
                             "name" => "Terminal A - Arrivals, LEX Pick Up",
                             "parentStation" => nil
                           }
                         }
                       },
                       %{
                         "node" => %{
                           "distance" => 528,
                           "place" => %{
                             "gtfsId" => "2272_2274:39",
                             "lat" => 42.369403,
                             "lon" => -71.019993,
                             "name" => "Terminal E - Departures",
                             "parentStation" => nil
                           }
                         }
                       },
                       %{
                         "node" => %{
                           "distance" => 528,
                           "place" => %{
                             "gtfsId" => "2272_2274:94",
                             "lat" => 42.3690332,
                             "lon" => -71.0191729,
                             "name" => "Terminal E – LEX Drop Off",
                             "parentStation" => nil
                           }
                         }
                       },
                       %{
                         "node" => %{
                           "distance" => 535,
                           "place" => %{
                             "gtfsId" => "2272_2274:71",
                             "lat" => 42.369077,
                             "lon" => -71.019247,
                             "name" => "Terminal E - Arrivals",
                             "parentStation" => nil
                           }
                         }
                       },
                       %{
                         "node" => %{
                           "distance" => 545,
                           "place" => %{
                             "gtfsId" => "mbta-ma-us:17095",
                             "lat" => 42.369344,
                             "lon" => -71.020238,
                             "name" => "Terminal E - Arrivals Level",
                             "parentStation" => nil
                           }
                         }
                       },
                       %{
                         "node" => %{
                           "distance" => 562,
                           "place" => %{
                             "gtfsId" => "2272_2274:9",
                             "lat" => 42.36949,
                             "lon" => -71.02036,
                             "name" => "Terminal E - Departures",
                             "parentStation" => nil
                           }
                         }
                       },
                       %{
                         "node" => %{
                           "distance" => 572,
                           "place" => %{
                             "gtfsId" => "2272_2274:1003",
                             "lat" => 42.3641545,
                             "lon" => -71.0199142,
                             "name" => "Now Entering Terminal B",
                             "parentStation" => nil
                           }
                         }
                       },
                       %{
                         "node" => %{
                           "distance" => 604,
                           "place" => %{
                             "gtfsId" => "2272_2274:8",
                             "lat" => 42.369808,
                             "lon" => -71.020765,
                             "name" => "Terminal E - Arrivals, LEX Pick Up",
                             "parentStation" => nil
                           }
                         }
                       },
                       %{
                         "node" => %{
                           "distance" => 606,
                           "place" => %{
                             "gtfsId" => "2272_2274:84",
                             "lat" => 42.366787,
                             "lon" => -71.016975,
                             "name" => "Terminal C - Arrivals",
                             "parentStation" => nil
                           }
                         }
                       },
                       %{
                         "node" => %{
                           "distance" => 607,
                           "place" => %{
                             "gtfsId" => "2272_2274:65",
                             "lat" => 42.36651,
                             "lon" => -71.017212,
                             "name" => "Terminal C - Departures",
                             "parentStation" => nil
                           }
                         }
                       },
                       %{
                         "node" => %{
                           "distance" => 607,
                           "place" => %{
                             "gtfsId" => "2272_2274:1001",
                             "lat" => 42.369999,
                             "lon" => -71.025167,
                             "name" => "Welcome to Logan",
                             "parentStation" => nil
                           }
                         }
                       }
                     ]
                   }
                 }
               })
    end
  end
end
