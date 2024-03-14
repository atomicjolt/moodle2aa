module Moodle2AA::Moodle2::Models::Quizzes
  class MultichoiceQuestion < Question
    register_question_type 'multichoice'
    register_question_type 'multichoicewiris'

    attr_accessor :single, :shuffle, :correctfeedback, :incorrectfeedback, :partiallycorrectfeedback
  end
end
