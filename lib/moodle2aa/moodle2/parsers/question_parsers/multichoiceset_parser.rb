module Moodle2AA::Moodle2
  class Parsers::QuestionParsers::MultichoicesetParser < Parsers::QuestionParsers::QuestionParser
    register_parser_type 'multichoiceset'

    def parse_question(node)
      # TODO: how to handles these question types
      super
    end
  end
end
