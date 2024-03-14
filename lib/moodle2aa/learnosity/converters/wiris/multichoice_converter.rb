require "byebug"

module Moodle2AA::Learnosity::Converters::Wiris
  class MultiChoiceConverter < Moodle2AA::Learnosity::Converters::MultiChoiceConverter
    register_converter_type "multichoicewiris"

    def convert_question(question)
      super
    end
  end
end
