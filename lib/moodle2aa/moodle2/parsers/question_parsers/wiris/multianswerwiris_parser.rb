
module Moodle2AA::Moodle2
  class Parsers::QuestionParsers::Wiris::MultianswerwirisParser < Moodle2AA::Moodle2::Parsers::QuestionParsers::Wiris::QuestionParser
    register_parser_type 'multianswerwiris'

    def parse_question(node)
      question = super

      plugin_node = node.at_xpath('plugin_qtype_multianswerwiris_question')

      answer_parser = Parsers::AnswerParser.new
      question.answers += plugin_node.search('answers/answer').map { |n| answer_parser.parse(n) }

      if sequence = plugin_node.at_xpath('multianswer/sequence')
        question.embedded_question_references = sequence.text.split(',')
      end

      # TODO: implement parsing out the sheet
      # Learnosity doesn't support variables in cloze question dropdowns

      question
    end
  end
end

