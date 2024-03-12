module Moodle2AA::Moodle2::Parsers
  module QuestionParsers
    require_relative 'question_parsers/question_parser'
    require_relative 'question_parsers/calculated_parser'
    require_relative 'question_parsers/match_parser'
    require_relative 'question_parsers/multianswer_parser'
    require_relative 'question_parsers/multichoice_parser'
    require_relative 'question_parsers/numerical_parser'
    require_relative 'question_parsers/shortanswer_parser'
    require_relative 'question_parsers/random_sa_parser'
    require_relative 'question_parsers/shortanswer_parser'
    require_relative 'question_parsers/true_false_parser'
    require_relative 'question_parsers/essay_parser'
    require_relative 'question_parsers/unknowntype_parser'
    require_relative 'question_parsers/gapselect_parser'

    module Wiris
      require_relative 'question_parsers/wiris/wiris_parser'
    end
  end
end
