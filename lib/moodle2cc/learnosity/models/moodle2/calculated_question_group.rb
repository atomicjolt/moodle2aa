module Moodle2CC::Learnosity::Models::Moodle2
  class CalculatedQuestionGroup < Moodle2CC::Moodle2::Models::Quizzes::Question
    attr_accessor :questions, :max_score

    def initialize
      super
      @questions = []
      @type = 'calculatedquestiongroup'
      @qtype = 'calculatedshared'
    end
  end
end
