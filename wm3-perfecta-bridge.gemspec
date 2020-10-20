# frozen_string_literal: true
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'wm3_perfecta_bridge/version'

Gem::Specification.new do |spec|
  spec.name          = "wm3_perfecta_bridge"
  spec.version       = Wm3PerfectaBridge::VERSION
  spec.authors       = ["Jesper Mellquist"]
  spec.email         = ["jesper.mellquist@hldesign.se"]

  spec.summary       = "WM3 Perfecta Bridge"
  spec.description   = "WM3 Perfecta store synchonize gem"
  spec.homepage      = "https://perfecta.se"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.add_runtime_dependency "rails", ">= 4.2", "< 5.0"
end

