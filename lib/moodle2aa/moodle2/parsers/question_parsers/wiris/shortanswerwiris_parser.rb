require 'byebug'

module Moodle2AA::Moodle2
  class Parsers::QuestionParsers::Wiris::ShortnswerwirisParser < Moodle2AA::Moodle2::Parsers::QuestionParsers::Wiris::QuestionParser
    # register_parser_type 'shortanswerwiris'

    def parse_question(node)
      question = super
      return question

      plugin_node = node.at_xpath('plugin_qtype_shortanswerwiris_question')

      answer_parser = Parsers::AnswerParser.new
      question.answers += plugin_node.search('answers/answer').map { |n| answer_parser.parse(n) }
      question.casesensitive = parse_boolean(plugin_node, 'shortanswer/usecase')

      # TODO: implement parsing out the sheet

      question
    end
  end
end
