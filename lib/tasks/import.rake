namespace :wm3_perfecta_bridge do
  desc 'import new customers'

  task(:import_customers => :environment) do
    Wm3PerfectaBridge::import("kund_perf", "customer")
  end

  task(:import_products => :environment) do
    Wm3PerfectaBridge::import("perf_art", "product")
  end

  task(:import_stock_items => :environment) do
    Wm3PerfectaBridge::import("art_perf", "stock_item")
  end

end
