module Wm3PerfectaBridge
  class ProductRelationImporter < Importer
    def self.type
      "product_relation"
    end

    def self.import(skus)
      @skus = skus
      @product = store.products.find_by(
        skus: @skus
      )
      unless @product
        Wm3PerfectaBridge::logger.info("Could not find product (#{skus})")
        return
      end
      current_product_relation_skus.each do |sku|
        destroy_product_relation(sku)
      end
      new_product_relations.each do |relation|
        add_product_relation(
          relation["Slav Artikelnummer"],
          relation["Relationstyp"]
        )
      end

    end

    private

    def self.add_product_relation(sku, type)
      return if current_product_relation_skus.include?(sku)
      return unless product = store.products.find_by(skus: sku)
      @product.product_relations.create(
        related_product_id: product.id,
        relation_id: relation(type).id
      )
    end

    def self.destroy_product_relation(sku)
      return unless new_product_relations.map{|s| s["Slav Artikelnummer"]}.include?(sku)
      return unless product = store.products.find_by(skus: sku)
      @product
        .product_relations
        .find_by(related_product_id: product.id)
        .destroy
    end

    def self.new_product_relations
      Importer.select("reservdel", "Huvud Artikelnummer" => @skus)
    end

    def self.current_product_relation_skus
      @product
        .product_relations
        .joins(:related_product)
        .map{|r| r.related_product.skus}
    end

    def self.relation(number)
      case number
      when "4"
        find_or_create_relation(store, "Utbytespumpar")
      else
        find_or_create_relation(store, "Reservdelar")
      end
    end
  end
end
