module Moodle2AA::Moodle2::Models::Quizzes
  class Answer
    attr_accessor :id, :answer_text, :answer_format, :fraction, :feedback, :feedback_format
    attr_accessor :answer_text_plain
  end
end
