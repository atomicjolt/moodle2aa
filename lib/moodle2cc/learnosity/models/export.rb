module Moodle2CC::Learnosity::Models
  class Export
    include JsonWriter
    attr_accessor :meta, :activities, :items, :questions, :_item_groups, :files, :features
    def initialize
      @meta = []
      @activities = []
      @items = []
      @questions = []
      @features = []
      @_item_groups = []
      @files = []
    end
  end
end
