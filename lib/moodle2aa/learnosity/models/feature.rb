module Moodle2AA::Learnosity::Models
  class Feature
    include JsonWriter

    attr_accessor :reference, :data, :type

    def initialize
      @data = {}
    end

    def reference_object
      return FeatureReference.new(self)
    end
    def scale_score(max_score)
      #nothing to do
    end
  end
end

