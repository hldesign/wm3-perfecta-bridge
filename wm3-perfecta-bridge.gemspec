# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "wm3_perfecta_bridge"
  spec.version       = "1.2.13"
  spec.authors       = ["Jesper Mellquist"]
  spec.email         = ["jesper.mellquist@hldesign.se"]

  spec.summary       = "WM3 Perfecta Bridge"
  spec.description   = "WM3 Perfecta store synchonize gem"
  spec.homepage      = "https://perfecta.se"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.add_dependency "rails", "~> 4.1.5"
end

