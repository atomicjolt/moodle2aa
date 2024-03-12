
require "byebug"

module Moodle2AA::Learnosity::Converters::Wiris
  class ShortAnswerConverter < Moodle2AA::Learnosity::Converters::QuestionConverter
    register_converter_type 'shortanswerwiris'

    def convert_question(question)
      byebug
    end
  end
end
