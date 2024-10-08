module Wm3PerfectaBridge
  class StockItemImporter < Importer

    KEY_FOR_SALDO = "Saldo"
    KEY_FOR_ARTIKELKOD = "Artikelkod"

    def self.type
      "stock_item"
    end

    def self.import(row)
      # Fetch new saldo
      new_saldo = row[KEY_FOR_SALDO]
      # Find product
      product = store.products.find_by("skus = ?", row[KEY_FOR_ARTIKELKOD])
      # Get stock item or create new
      unless product
        Wm3PerfectaBridge::logger.info("Could not find product (#{row[KEY_FOR_ARTIKELKOD]})")
        return
      end
      stock_item = product.stock_items.find_or_create_by(store: store, product_id: product.id)
      # Difference in stock slado
      diff = new_saldo.to_i - stock_item.quantity
      # Create stock item movement
      stock_item.move(diff)
      Wm3PerfectaBridge::logger.info("Updated stock for #{product.skus} (#{stock_item.quantity})")
    end
  end
end
