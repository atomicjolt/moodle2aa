module Moodle2CC::Learnosity::Models
  class Activity
    include JsonWriter

    attr_accessor :reference, :data, :tags, :description, :status, :description, :title

    def initialize
      @data = ActivityDefinition.new 
      @tags = {}
    end
  end
end

