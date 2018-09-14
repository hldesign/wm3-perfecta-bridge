namespace :wm3_perfecta_bridge do
  desc 'import all [folder_name]'
  task :import_all_from, [:folder] => [:environment] do |t, folder|
    if folder
      Wm3PerfectaBridge::config["file_path"] << folder
    end

    Wm3PerfectaBridge::import("perf_art", "product")
    Wm3PerfectaBridge::import("kund_perf", "customer")
    Wm3PerfectaBridge::import("art_perf", "stock_item")
    Wm3PerfectaBridge::import("reservdel", "product_relation")

    if folder
      Wm3PerfectaBridge::config["file_path"] = 
        Wm3PerfectaBridge::config["file_path"].gsub(folder, "") 
    end
  end

  desc 'import all'
  task(:import_all => :environment) do
    Wm3PerfectaBridge::import("perf_art", "product")
    Wm3PerfectaBridge::import("kund_perf", "customer")
    Wm3PerfectaBridge::import("art_perf", "stock_item")
    Wm3PerfectaBridge::import("reservdel", "product_relation")
  end

  desc 'export to csv and send mail'
  task(:export => :environment) do
    Wm3PerfectaBridge::Reporter.export("prices")
  end

  desc 'import customers'
  task(:import_customers => :environment) do
    Wm3PerfectaBridge::import("kund_perf", "customer")
  end

  desc 'import products'
  task(:import_products => :environment) do
    Wm3PerfectaBridge::import("perf_art", "product")
  end

  desc 'import stock items'
  task(:import_stock_items => :environment) do
    Wm3PerfectaBridge::import("art_perf", "stock_item")
  end

end
