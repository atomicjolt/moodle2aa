module Moodle2AA::Moodle2::Models::Quizzes
  require_relative 'quizzes/answer'
  require_relative 'quizzes/question'
  require_relative 'quizzes/question_category'
  require_relative 'quizzes/quiz'
  require_relative 'quizzes/calculated_question'
  require_relative 'quizzes/match_question'
  require_relative 'quizzes/multianswer_question'
  require_relative 'quizzes/multichoice_question'
  require_relative 'quizzes/numerical_question'
  require_relative 'quizzes/shortanswer_question'
  require_relative 'quizzes/random_sa_question'
  require_relative 'quizzes/true_false_question'
  require_relative 'quizzes/essay_question'
  require_relative 'quizzes/unknowntype_question'
  require_relative 'quizzes/gapselect_question'

  module Wiris
    require_relative 'quizzes/wiris/wiris_question'
    require_relative 'quizzes/wiris/multianswerwiris_question'
    require_relative 'quizzes/wiris/shortanswerwiris_question'
    require_relative 'quizzes/wiris/multichoicewiris_question'
  end
end

