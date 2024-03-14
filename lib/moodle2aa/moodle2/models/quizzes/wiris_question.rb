module Moodle2AA::Moodle2::Models::Quizzes
  class WirisQuestion < Question
    register_question_type 'shortanswerwiris'
    # register_question_type 'multichoicewiris'
    register_question_type 'matchwiris'
    register_question_type 'multianswerwiris'
    register_question_type 'essaywiris'
    register_question_type 'truefalsewiris'

    attr_accessor :code

  end
end
