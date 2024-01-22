module Moodle2AA::Moodle2
  class Parsers::QuestionParsers::ShortanswerParser < Parsers::QuestionParsers::QuestionParser
    include Parsers::ParserHelper
    register_parser_type('shortanswer')

    def parse_question(node)
      question = super

      answer_parser = Parsers::AnswerParser.new
      question.answers += node.search('answers/answer').map { |n| answer_parser.parse(n) }
      question.casesensitive = parse_boolean(node, 'plugin_qtype_shortanswer_question/shortanswer/usecase')

      question
    end

  end
end
