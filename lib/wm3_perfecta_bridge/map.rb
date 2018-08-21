module Wm3PerfectaBridge
  class Map

    def self.each_value(name = nil)
      map(name).each do |m|
        yield m.values.first
      end
    end

    def self.[](key, name= nil)
      value = map(name).find{|m| m[key]}
      value == nil ? nil : value[key]
    end

    def self.each(name = nil)
      map(name).each{|h| yield h.keys.first, h.values.first}
    end

    private

    def self.map(name)
      name == nil ? @map : instance_variable_get("@#{name}")
    end

  end
end

