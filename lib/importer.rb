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

    protected

    def self.country
      @country ||= store.countries.find_by(name: "Sweden")
    end

    def self.store
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

    def self.create_property_values(store, variant, properties = {})
      properties.map do |name, data|
        property = store.properties.find_or_create_by(name: name) do |new_property|
          new_property.presentation = { 'sv' => name }
          new_property.property_type = data[:property_type] || 'text'
          new_property.measurement_unit = data[:measurement_unit] || nil
        end
        variant.product_properties.where(property: property).destroy_all
        data[:property_values].map do |value|
          # Do not try to save if nil
          next if value.blank?
          # Find or create property value
          property_value = store.property_values
            .find_or_create_by(property: property, name: value.to_s) do |prop|
            prop.presentation = { 'sv' => value}
          end
          # Connect variant to product property value
          variant.product_properties.new(
            property: property,
            property_value: property_value,
            position: data[:position] || 0
          )
        end
      end.flatten
    end
  end
end
