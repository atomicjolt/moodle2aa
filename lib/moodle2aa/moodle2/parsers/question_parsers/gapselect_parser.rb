module Moodle2AA::Moodle2
  class Parsers::QuestionParsers::GapselectParser < Parsers::QuestionParsers::QuestionParser
    include Parsers::ParserHelper
    register_parser_type('gapselect')

    def parse_question(node)
      question = super

      answer_parser = Parsers::AnswerParser.new
      question.answers += node.search('answers/answer').map { |n| answer_parser.parse(n) }

      question.shuffleanswers = parse_boolean(node.search('gapselect'), 'shuffleanswers')
      question.shownumcorrect = parse_boolean(node.search('gapselect'), 'shownumcorrect')
      question.correctfeedback = parse_text(node.search('gapselect'), 'correctfeedback')
      question.partiallycorrectfeedback = parse_text(node.search('gapselect'), 'partiallycorrectfeedback')
      question.incorrectfeedback = parse_text(node.search('gapselect'), 'incorrectfeedback')

      question
    end

  end
end
