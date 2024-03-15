require 'byebug'

module Moodle2AA::Moodle2
  class Parsers::QuestionParsers::Wiris::ShortnswerwirisParser < Moodle2AA::Moodle2::Parsers::QuestionParsers::Wiris::QuestionParser
    register_parser_type 'shortanswerwiris'

    def parse_question(node)
      question = super

      plugin_node = get_plugin_node(node, 'shortanswerwiris')

      answer_parser = Parsers::AnswerParser.new
      question.answers += plugin_node.search('answers/answer').map { |n| answer_parser.parse(n) }
      question.casesensitive = parse_boolean(plugin_node, 'shortanswer/usecase')

      question.algorithms, question.algorithms_format = get_code(node, 'shortanswerwiris')

      question
    end
  end
end
