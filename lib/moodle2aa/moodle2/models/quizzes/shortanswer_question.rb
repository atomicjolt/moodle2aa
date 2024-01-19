module Moodle2AA::Moodle2::Models::Quizzes
  class ShortanswerQuestion < Question
    register_question_type 'shortanswer'
    attr_accessor :casesensitive
  end
end
