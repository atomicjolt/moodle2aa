module Moodle2AA::Moodle2::Models::Quizzes
  class NumericalQuestion < Question
    register_question_type 'numerical'
    attr_accessor :tolerances, :units, :showunits, :unitsleft, :unitgradingtype, :unitpenalty

    def initialize
      super
      @tolerances = {}
      @units = []
    end
  end
end
