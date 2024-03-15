module Moodle2AA::Learnosity
  module Converters
    require_relative 'converters/converter_helper'
    require_relative 'converters/question_converter'
    require_relative 'converters/numerical_converter'
    require_relative 'converters/shortanswer_converter'
    require_relative 'converters/manual_converter'
    require_relative 'converters/multichoice_converter'
    require_relative 'converters/multianswer_converter'
    require_relative 'converters/truefalse_converter'
    require_relative 'converters/calculated_converter'
    #require_relative 'converters/quiz_page_group_converter'
    require_relative 'converters/match_converter'
    require_relative 'converters/expression_converter'
    require_relative 'converters/eval_error'
    require_relative 'converters/moodle_eval'
    require_relative 'converters/overrides'
    require_relative 'converters/essay_converter'
    require_relative 'converters/random_converter'
    require_relative 'converters/question_bank_converter'
    require_relative 'converters/assignment_converter'
    require_relative 'converters/html_converter'
    require_relative 'converters/file_converter'
    require_relative 'converters/gapselect_converter'

    module Wiris
      require_relative 'converters/wiris/multichoice_converter'
      require_relative 'converters/wiris/shortanswerwiris_converter'
      require_relative 'converters/wiris/multianswerwiris_converter'
    end
  end
end
