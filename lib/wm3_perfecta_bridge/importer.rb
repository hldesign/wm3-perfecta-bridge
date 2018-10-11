module Wm3PerfectaBridge
  class Importer
    # Importer
    def self.import(row, type)
      importer = descendants.find {|i| type == i.type}
      if importer
        importer.import(row)
      end
    end

    def self.read_csv(filename)
      CSV.read("#{Rails.root}/#{Wm3PerfectaBridge::config["file_path"]}/#{filename}",
               col_sep: ";",
               encoding: "iso-8859-1:utf-8",
               headers: true, quote_char: "\x00").map(&:to_h)
    end

    def self.find(filename, args = {})
      file = read_csv(PyramidFilesMap[filename])
      file.find{|p| p[args.keys.first] == args.values.first}
    end

    def self.select(filename, args = {})
      file = read_csv(PyramidFilesMap[filename])
      file.select{|p| p[args.keys.first] == args.values.first}
    end

    # trash products which in wm3 which are absent from
    # the XML file PERF_ART.
    def self.trash_absent_products(codes)
      old_codes = store.products.pluck(:skus) - codes
      store.products.where(skus: old_codes).each do |product|
        product.trash
      end
    end
    
    # delete all product property values which no product is using.
    def self.delete_unused_property_values
      ids = store
        .property_values
        .joins(:product_properties)
        .group("shop_property_values.id")
        .having("COUNT(shop_product_properties) <= 0")
        .pluck("shop_property_values.id")
      Wm3PerfectaBridge::logger.info("Found #{ids} unused property_values")
      store.property_values.where(id: ids).destroy_all
    end

    protected

    def self.country
      @country ||= store.countries.find_by(name: "Sweden")
    end

    def self.store
      if Rails.env == "test"
        return @store ||= Shop::Store.first
      end
      @store ||= Shop::Store.find(Wm3PerfectaBridge::config["store_id"])
    end

    def self.find_or_create_relation(store, name)
      store.relations.find_or_create_by(name: name) do |new_relation|
        new_relation.bilateral = true
      end
    end

    def self.find_or_create_price_list(name)
      instance_name = name.to_url.gsub("-", "_")
      value = instance_variable_get("@#{instance_name}")
      return value if value.present?
      list = store.price_lists.where("name = ?", name).first
      unless list
        list = store.price_lists.new
        list.name = name
        list.save
      end
      instance_variable_set("@#{instance_name}", list)
    end

    def self.find_or_create_group(name)
      instance_name = name.to_url.gsub("-", "_")
      value = instance_variable_get("@#{instance_name}")
      return value if value.present?
      group = store.groups.where("url = ?", name.to_url).first
      unless group
        group = store.groups.new
        group.name = name
        group.save
      end
      instance_variable_set("@#{instance_name}", group)
    end

    def self.create_property_values(variant, **data)
      property = store.properties.find_or_create_by(name: data[:property_name]) do |new_property|
        new_property.presentation = { 'sv' => data[:property_name] }
        new_property.property_type = data[:property_type] || 'text'
        new_property.measurement_unit = data[:measurement_unit] || nil
      end
      # Do not try to save if nil
      return if data[:property_value].blank?
      if product_property = variant.product_properties.find_by(property_id: property.id)
        return if product_property.property_value.name == data[:property_value]
        product_property.delete
      end
      # Find or create property value
      if property.property_type == "number" 
        data[:property_value] = data[:property_value].gsub(/[^0-9]/, "")
      end
      property_value = store.property_values.find_or_create_by(property: property, name: data[:property_value].to_s) do |prop|
        prop.presentation = { 'sv' => data[:property_value] }
      end
      if property_value.blank?
        Wm3PerfectaBridge::logger.info("Could not create or find product property. (#{variant.sku}, #{data[:property_value]})")
      end
      # Connect variant to product property value
      variant.product_properties.create(
        property: property,
        property_value: property_value,
        position: data[:position] || 0
      )
    end
  end
end
