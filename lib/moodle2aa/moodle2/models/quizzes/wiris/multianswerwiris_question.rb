
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
  end
end
