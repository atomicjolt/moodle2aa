module Moodle2CC::Learnosity::Models
  class ActivityConfig
    include JsonWriter
    
    attr_accessor :navigation, :regions, :title

    def initialize
      @navigation = ActivityNavigation.new
    end
  end
end

