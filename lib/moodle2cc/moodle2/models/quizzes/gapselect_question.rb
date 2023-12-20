module Moodle2CC::Moodle2::Models::Quizzes
  class GapselectQuestion < Question
    register_question_type 'gapselect'
    attr_accessor :shuffleanswers, :correctfeedback, :incorrectfeedback, :partiallycorrectfeedback, :shownumcorrect
  end
end
