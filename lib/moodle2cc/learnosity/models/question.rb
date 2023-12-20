module Moodle2CC::Learnosity::Models
  class Question
    include JsonWriter

    attr_accessor :reference, :data, :type

    def initialize
      @data = {}
      @data[:metadata] = {}
      @_save = {score: nil, altscore: []}
    end

    def reference_object
      return QuestionReference.new(self)
    end

    def scale_score(max_score)
      if !data[:validation]
        return #nothing to do
      end
      max_score = max_score.to_f 
      _scale_score(max_score)
    end

    # scale all scores by max_score
    # save a copy before scaling, in case we have to unscale from 0 (it happens!)
    def _scale_score(max_score)
      if data[:validation][:valid_response]
        response = data[:validation][:valid_response]
        @_save[:score] ||= response[:score]
        response[:score] = max_score * @_save[:score]
      end
      if data[:validation][:alt_responses]
        data[:validation][:alt_responses].each_with_index do |response, n|
          @_save[:altscore][n] ||= response[:score]
          response[:score] = max_score * @_save[:altscore][n]
        end
      end
    end
  end
end

