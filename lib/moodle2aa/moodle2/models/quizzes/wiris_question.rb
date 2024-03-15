module Moodle2AA::Moodle2::Models::Quizzes
  class WirisQuestion < Question
    register_question_type 'shortanswerwiris'
    register_question_type 'multianswerwiris'

    attr_accessor :code
  end
end
