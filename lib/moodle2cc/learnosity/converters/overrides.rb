require 'json'

module Moodle2CC::Learnosity::Converters
  class Overrides

    def initialize()
      # hack to cleanup the mess created by bundling.  read a json file to get
      # manual questions the PAs already converted.
      manualfile = File.dirname(__FILE__)+'/overrides.json'
      file = File.read(manualfile)
      @overrides = JSON.parse(file) 
      raise "unable to load overrides" if !@overrides
    end

    @@instance = Overrides.new

    def self.instance
      return @@instance
    end

    def get_override(reference)
      @overrides[reference]
    end
  end
end
