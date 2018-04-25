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
      # Create and assign product relations
      product_relations = Importer.select("reservdel", "Huvud Artikelnummer" => row["Artikelkod"]).map do |r|
        # Check if product is created else save relation for futher use
        slave = store.products.find_by(skus: r["Slav Artikelnummer"])
        if slave.present?
          new_product_relations(r, slave)
        else
          @stored_relations << {
            slave: r["Slav Artikelnummer"],
            relation: r
          }
          Wm3PerfectaBridge::logger.info("Product relation #{r['Slav Artikelnummer']} was stored")
          nil
        end
      end.compact
      # Ignore product relation update if product_relation is empty or relation does exists in files
      if product_relations.present? || Importer.select("reservdel", "Slav Artikelnummer" => row["Artikelkod"]).blank?
        product.product_relations = product_relations
      end
      # Append "Effekt", "Flöde" and "Tryck" to product row if they exists
      values = Importer.select("kapacitet", {"Artikelnummer" => row["Artikelkod"]})
      if values.present?
        ["Effekt", "Flöde", "Tryck"].each do |value|
          row[value] = values.map{|k| k[value] }.to_json
        end
      end
      # Create product properties
      product_properties = product_properties_map(row).map do |name, type|
        next unless row[name].present?
        # concat all values from KAPACITETET file into json.
        properties = {name => { property_values: [row[name]], property_type: type}}
        create_property_values(store, product.master, properties)
      end.flatten.compact
      product.product_properties = product_properties
      # Find or create product group and append product to it
      ["Artikeltyp", "Varugrupp", "Artikelstatus"].map do |group|
        name = row[self.const_get("KEY_FOR_#{group.upcase}")]
        name = "Artikelstatus #{name}" if group == "Artikelstatus"
        next if name.blank? || product.groups.where(url: name.try(:to_url)).present?
        product.groups << find_or_create_group(name)
      end
      if product.save
        Wm3PerfectaBridge::logger.info("Successfully saved product #{product.master.sku}")
        # Search in old product relations and create them
        stored_relations = @stored_relations.select do |v|
          v[:slave] == row[KEY_FOR_ARTIKELKOD]
        end
        # Connect stored_relations to relative master product
        connect_stored_relations(stored_relations, product)
        # Set prices for product for each price_list
        set_prices_for_price_lists(row["Prisgrupp"], product)
        # Set product backorderable
        stock_item = product.stock_items.find_or_create_by(store: store, product_id: product.id)
        stock_item.backorderable = (row[KEY_FOR_BACKORDERABLE] == "2")
      else
        Wm3PerfectaBridge::logger.error("Could not save product #{product.master.sku}")
      end
    end

    private

    def self.product_properties_map(row)
      ProductMap.properties.map{|t| t.to_a.flatten}
    end

    def self.connect_stored_relations(stored_relations, product)
      # Ignore if no relations was found
      return unless stored_relations.present?
      # Group relations and handle them to master products
      stored_relations.group_by{|v| v[:relation]["Huvud Artikelnummer"]}.each do |master, relations|
        # Fetch master product
        master_product = store.products.find_by(skus: master)
        if master_product.blank?
          Wm3PerfectaBridge::logger.error("Could not find master products skus for master #{master}")
          next
        end
        # Create product relations
        product_relations = relations.map{|r| new_product_relations(r, master_product)}
        # Append product relations
        product.product_relations = product_relations
        Wm3PerfectaBridge::logger.info("Relations for product #{master_product.skus} was successfully created from stored relations")
        # Delete product relations from stored relations
        relations.each {|relation| @stored_relations.delete(relation)}
      end
    end

    def self.new_product_relations(pr, product)
      relation(store, pr["Relationstyp"]).product_relations.new({
        related_product: product
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
          discount_multiplier = (100 - pl["%"].to_f)
          # Set new price to product price
          price.discount_multiplier = discount_multiplier
          # Save Price
          price.save
        end
      end
    end
  end
end
