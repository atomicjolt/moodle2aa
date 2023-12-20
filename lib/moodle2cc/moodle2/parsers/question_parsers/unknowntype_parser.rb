module Moodle2CC::Moodle2
  class Parsers::QuestionParsers::UnknownTypeParser < Parsers::QuestionParsers::QuestionParser
    include Parsers::ParserHelper
    register_parser_type('unknowntype')

    def parse_question(node)
      question = super
    end

  end
end