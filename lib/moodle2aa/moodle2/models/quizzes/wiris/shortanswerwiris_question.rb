
module Moodle2AA::Moodle2::Models::Quizzes::Wiris
  class ShortAnswerWirisQuestion < WirisQuestion
    register_question_type 'shortanswerwiris'

    attr_accessor :casesensitive
  end
end
