module Moodle2CC::Learnosity::Models
  class QuestionReference < Reference
    include JsonWriter

    attr_accessor :type

    def initialize(question)
      @type = question.type
      super question
    end
  end
end

