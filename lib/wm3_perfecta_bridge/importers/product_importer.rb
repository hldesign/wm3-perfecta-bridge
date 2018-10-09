module Wm3PerfectaBridge
  class ProductImporter < Importer

    @stored_relations = []

    KEY_FOR_ARTIKELKOD = 'Artikelkod'
    KEY_FOR_ARTIKELSTATUS = "Artikelstatus"
    KEY_FOR_ARTIKELTYP = 'Artikeltyp'
    KEY_FOR_BACKORDERABLE = "Köpbar/beställning webb"
    KEY_FOR_VARUGRUPP = 'Varugrupp'

    def self.type
      "product"
    end

    def self.import(row)
      product = store.products.find_by(skus: row[KEY_FOR_ARTIKELKOD])
      unless product.present?
        product = store.products.new
        product.available_on = DateTime.now
      end
      # Adjust row values
      row["Benämning"] = row["Benämning"].gsub("<=", "≤")
      # Assign properties
      assign_properties(product, row)
      # Product for sale?
      product.master.for_sale = !(row[KEY_FOR_ARTIKELSTATUS] == "Z")
      # Product is customer group specific?
      product.customer_group_specific = (row[KEY_FOR_ARTIKELSTATUS] == "2")
      # Set product price
      product.master.amount = row["Grundpris"]
      # Append "Effekt", "Flöde" and "Tryck" to product row if they exists
      values = Importer.select("kapacitet", {"Artikelnummer" => row["Artikelkod"]})
      if values.present?
        ["Effekt", "Flöde", "Tryck"].each do |value|
          row[value] = values.map{|k| k[value] }.to_json
        end
      end
      # Find or create product group and append product to it
      ["Artikeltyp", "Varugrupp", "Artikelstatus"].map do |group|
        name = row[self.const_get("KEY_FOR_#{group.upcase}")]
        name = "Artikelstatus #{name}" if group == "Artikelstatus"
        next if name.blank? || product.groups.where(url: name.try(:to_url)).present?
        product.groups << find_or_create_group(name)
      end
      if product.save
        Wm3PerfectaBridge::logger.info("Successfully saved product #{product.master.sku}")
        # Set prices for product for each price_list
        set_prices_for_price_lists(row["Prisgrupp"], product)
        # Set product backorderable
        stock_item = product.stock_items.find_or_create_by(store: store, product_id: product.id)
        if stock_item.backorderable != (row[KEY_FOR_BACKORDERABLE] == "2")
          stock_item.update_attribute(:backorderable, row[KEY_FOR_BACKORDERABLE])
        end
      else
        Wm3PerfectaBridge::logger.error("Could not save product #{product.master.sku}")
      end
      # Create product properties
      product_properties_map(row).each do |name, type|
        unless row[name].present?
          next unless property = store.properties.find_by(name: name)
          next unless product_property = product.product_properties.find_by(property_id: property.id)
          next if product_property.delete
        end
        row[name] = "Våt" if row[name] == "VÅT"
        row[name] = "Torr" if row[name] == "TORR"
        create_property_values(
          product.master, 
          property_name: name,
          property_value: row[name],
          property_type: type
        )
      end
    end

    private

    def self.product_properties_map(row)
      ProductMap.properties.map{|t| t.to_a.flatten}
    end

    def self.new_product_relation(pr, product)
      relation(store, pr["Relationstyp"]).product_relations.new({
        related_product_id: product.id
      })
    end

    def self.relation(store, number)
      case number
      when "4"
        return find_or_create_relation(store, "Utbytespumpar")
      else
        return find_or_create_relation(store, "Reservdelar")
      end
    end

    def self.assign_properties(product, row)
      ["product", "master"].each do |type|
        ProductMap.each(type) do |attr, value|
          case type
          when "product"
            product.send("#{attr}=", row[value])
          when "master"
            product.master.send("#{attr}=", row[value])
          end
        end
      end
    end

    def self.set_prices_for_price_lists(list_category, product)
      Importer.select("prislista", {"Kod" => list_category}).each do |pl|
        if pl["%"].to_f > 0
          # Find price list
          price_list = find_or_create_price_list(pl["Beteckning"])
          # Get product price from price list
          price = price_list.prices.find_by(product_id: product.id)
          unless price
            Wm3PerfectaBridge::logger.info("Product price could not be found (#{product.master.sku}, #{pl["Beteckning"]})")
            return
          end
          # Calculate new price
          price.amount = product.master.price.amount
          discount = pl["%"].to_f
          # Set new price to product price
          price.discount = discount
          # Save Price
          price.save
        end
      end
    end
  end
end
