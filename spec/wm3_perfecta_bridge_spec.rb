require "spec_helper"

RSpec.describe Wm3PerfectaBridge do
  it "has a version number" do
    expect(Wm3PerfectaBridge::VERSION).not_to be nil
  end

  it "finds all csv files" do
    Wm3PerfectaBridge::PyramidFilesMap.each do |file|
      expect(Wm3PerfectaBridge::read_csv(file)).not_to be nil
    end
  end
end
