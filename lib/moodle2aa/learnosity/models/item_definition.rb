module Moodle2AA::Learnosity::Models
  class ItemDefinition
    include JsonWriter

    attr_accessor :widgets, :template

    def initialize
      @widgets = []
    end
  end
end

