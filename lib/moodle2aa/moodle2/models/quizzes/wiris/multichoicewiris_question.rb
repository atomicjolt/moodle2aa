module Moodle2AA::Moodle2::Models::Quizzes::Wiris
  class MultichoiceWirisQuestion < WirisQuestion
    register_question_type 'multichoicewiris'

    attr_accessor :single, :shuffle, :correctfeedback, :incorrectfeedback, :partiallycorrectfeedback
  end
end
