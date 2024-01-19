module Moodle2AA::Learnosity::Models
  class ActivityDefinition
    include JsonWriter

    attr_accessor :items, :config, :rendering_type

    def initialize
      @items = []
      @config = ActivityConfig.new
    end
  end
end

