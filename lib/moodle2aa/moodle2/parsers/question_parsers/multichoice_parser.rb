module Moodle2AA::Moodle2
  class Parsers::QuestionParsers::MultichoiceParser < Parsers::QuestionParsers::QuestionParser
    include Parsers::ParserHelper
    register_parser_type('multichoice')

    def parse_question(node)
      question = super

      answer_parser = Parsers::AnswerParser.new
      question.answers += node.search('answers/answer').map { |n| answer_parser.parse(n) }

      question.single = parse_boolean(node, 'plugin_qtype_multichoice_question/multichoice/single')
      question.shuffle = parse_boolean(node.search('multichoice'), 'shuffleanswers')
      question.correctfeedback = parse_text(node.search('multichoice'), 'correctfeedback')
      question.partiallycorrectfeedback = parse_text(node.search('multichoice'), 'partiallycorrectfeedback')
      question.incorrectfeedback = parse_text(node.search('multichoice'), 'incorrectfeedback')

      question
    end

  end
end
