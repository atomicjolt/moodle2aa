module Moodle2CC::Learnosity::Models
  class FeatureReference < Reference
    include JsonWriter

    attr_accessor :type

    def initialize(feature)
      @type = feature.type
      super feature
    end
  end
end

