module Wm3PerfectaBridge
  class ProductMap < Map

    # WM3 attribute name => Perfecta Pyramid column name
    @product = [
      {"name" => "Benämning"}
    ]

    # WM3 attribute name => Perfecta Pyramid column name
    @master = [
      {"sku" => "Artikelkod"}
    ]

    # WM3 property name (perf_art) => WM3 property type
    @properties = [
      {"Anslutningstyp" => "text"},
      {"Axel" => "text"},
      {"Artikelstatus" => "text"},
      {"Bygglängd" => "number"},
      {"DN" => "number"},
      {"EEI" => "number"},
      {"Effekt" => "text"},
      {"Flöde" => "text"},
      {"Frekvens" => "number"},
      {"Höjd" => "number"},
      {"Kalkyltyp" => "text"},
      {"Kapacitetsreglerad" => "text"},
      {"MEI" => "number"},
      {"Material axeltätning" => "text"},
      {"Max omgivningstemp" => "number"},
      {"Max vätsketemp" => "number"},
      {"Min vätsketemp" => "number"},
      {"Motorskydd krävs" => "text"},
      {"Motortyp" => "text"},
      {"Märkström max" => "number"},
      {"Nettovikt" => "number"},
      {"PDF-dokument" => "text"},
      {"Packningar" => "text"},
      {"Pelarmått" => "number"},
      {"PumpKategori" => "text"},
      {"Pumpbild" => "text"},
      {"Pumphjul" => "text"},
      {"Pumphus" => "text"},
      {"Skyddsform" => "number"},
      {"Spänning" => "text"},
      {"Tillförd effekt max" => "number"},
      {"Tryck" => "text"},
      {"Tvilling" => "text"},
      {"Varvtal" => "number"},
      {"Vikt" => "number"},
      {"Fas" => "number"},
      {"Prisgrupp" => "text"}
    ]

    def self.properties
      @properties
    end

  end
end
