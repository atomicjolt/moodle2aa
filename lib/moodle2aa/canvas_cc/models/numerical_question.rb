module Moodle2AA::CanvasCC::Models
  class NumericalQuestion < Question
    register_question_type 'numerical_question'

    attr_accessor :tolerances
  end
end