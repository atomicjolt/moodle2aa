require 'byebug'

module Moodle2AA::Moodle2
  class Parsers::QuestionParsers::Wiris::ShortAnswerParser < Moodle2AA::Moodle2::Parsers::QuestionParsers::Wiris::QuestionParser
    register_parser_type 'shortanswerwiris'

    def parse_question(node)
      question = super
      answers = get_answers(node, question.type)
      # byebug if ["Q1", "The Red Riding Hood"].include?(question.name)

      question.code = get_code(node, question.type)
      question
    end
  end
end
