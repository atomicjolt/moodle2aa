module Moodle2AA::Learnosity::Models
  class Item

    include JsonWriter

    attr_accessor :reference, :metadata, :definition, :status, :questions, :features, :tags, :title
    attr_accessor :note, :source, :description, :dynamic_content_data

    def initialize
      @definition = ItemDefinition.new
      @questions = []
      @features = []
      @tags = {}
    end
  end
end

