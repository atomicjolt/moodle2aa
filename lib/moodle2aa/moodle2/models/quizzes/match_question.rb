module Moodle2AA::Moodle2::Models::Quizzes
  class MatchQuestion < Question
    register_question_type 'match'
    register_question_type 'matchwiris'

    attr_accessor :matches
    attr_accessor :shuffle, :correctfeedback, :incorrectfeedback, :partiallycorrectfeedback

    def initialize
      super
      @matches = []
    end
  end
end
