module Moodle2CC::Learnosity::Models
  class LearnosityFile
    
    include JsonWriter

    attr_accessor :_file_location, :mime_type, :name, :file_path
    attr_accessor :name, :_usage_count, :identifier
    attr_accessor :_component, :_file_area, :_item_id

    def initialize
      @_usage_count = 0
    end

  end
end
