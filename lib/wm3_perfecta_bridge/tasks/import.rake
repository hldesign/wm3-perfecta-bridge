namespace :wm3_perfecta_bridge do
  desc 'import all'
  task(:import_all => :environment) do
    Wm3PerfectaBridge::import("kund_perf", "customer")
    Wm3PerfectaBridge::import("perf_art", "product")
    Wm3PerfectaBridge::import("art_perf", "stock_item")
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
