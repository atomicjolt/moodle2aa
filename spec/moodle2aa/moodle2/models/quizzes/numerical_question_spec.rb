require 'spec_helper'

module Moodle2AA::Moodle2::Models::Quizzes
  describe NumericalQuestion do

    it_behaves_like 'a Moodle2AA::Moodle2::Models::Quizzes::Question'

    it_behaves_like 'it has an attribute for', :tolerances, {}

    it_behaves_like 'it is registered as a Question', 'numerical'
  end
end