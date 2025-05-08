module Moodle2AA::Moodle2
  class Parsers::QuestionParsers::MultichoicewirisParser < Parsers::QuestionParsers::Wiris::QuestionParser
    register_parser_type 'multichoicewiris'

    # NOTE that this question type doesn't resolve any wiris variables
    def parse_question(node)
      question = super

      plugin_node = get_plugin_node(node, 'multichoicewiris')

      answer_parser = Parsers::AnswerParser.new
      question.answers += plugin_node.search('answers/answer').map { |n| answer_parser.parse(n) }

      question.single = parse_boolean(plugin_node, 'multichoice/single')
      question.shuffle = parse_boolean(plugin_node.search('multichoice'), 'shuffleanswers')
      question.correctfeedback = parse_text(plugin_node.search('multichoice'), 'correctfeedback')
      question.partiallycorrectfeedback = parse_text(plugin_node.search('multichoice'), 'partiallycorrectfeedback')
      question.incorrectfeedback = parse_text(plugin_node.search('multichoice'), 'incorrectfeedback')

      question
    end
  end
end
