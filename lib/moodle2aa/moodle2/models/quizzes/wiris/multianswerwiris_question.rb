
module Moodle2AA::Moodle2::Models::Quizzes::Wiris
  class MultiansweWirisQuestion < WirisQuestion
    register_question_type 'multianswerwiris'

    attr_accessor :embedded_question_references, :embedded_questions

    def initialize
      super
      @embedded_questions = []
    end

    def resolve_embedded_question_references(question_categories)
      return unless @embedded_question_references

      @embedded_questions ||= []
      @embedded_question_references.each do |ref|
        question = nil
        question_categories.each do |qc|
          if question = qc.questions.detect{|q| q.id.to_s == ref && q.parent.to_s == @id}
            qc.questions.delete(question)
            break
          end
        end

        @embedded_questions << question if question
      end
    end


    def substitution_variables
      return @substitution_variables if @substitution_variables

      @substitution_variables = super

      embedded_questions.each do |question|
        question.answers.each do |answer|
          @substitution_variables.merge(answer.answer_text.scan(SUBSTITUTION_VARIABLE_REGEX).flatten)
        end
      end

      @substitution_variables
    end

    def script_variables
      @script_variables ||= super.merge(embedded_questions.map(&:script_variables).to_set.flatten)
    end
  end
end
