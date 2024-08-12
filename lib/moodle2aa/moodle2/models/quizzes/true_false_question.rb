module Moodle2AA::Moodle2::Models::Quizzes
  class TrueFalseQuestion < Question
    register_question_type 'truefalse'
    register_question_type 'truefalsewiris'
    attr_accessor :true_false_id, :true_answer, :false_answer
  end
end
