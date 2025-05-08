
module Moodle2AA::Moodle2
  class Parsers::QuestionParsers::Wiris::TrufalsewirisParser < Moodle2AA::Moodle2::Parsers::QuestionParsers::Wiris::QuestionParser
    register_parser_type 'truefalsewiris'

    def parse_question(node)
      question = super
      plugin_node = node.at_xpath('plugin_qtype_truefalsewiris_question')
      question.true_false_id = plugin_node.at_xpath('truefalse/@id').value
      question.true_answer = parse_text(plugin_node, 'truefalse/trueanswer')
      question.false_answer = parse_text(plugin_node, 'truefalse/falseanswer')

      answer_parser = Parsers::AnswerParser.new
      question.answers += plugin_node.search('answers/answer').map { |n| answer_parser.parse(n) }

      question
    end
  end
end
