require "mathml2asciimath"
require "byebug"

module Moodle2AA::Moodle2::Models::Quizzes::Wiris
  class WirisQuestion < Moodle2AA::Moodle2::Models::Quizzes::Question
    attr_accessor :algorithms
    attr_accessor :algorithms_format

    # Variables can be in: question_text, answers[*].answer_text,
  end
end
