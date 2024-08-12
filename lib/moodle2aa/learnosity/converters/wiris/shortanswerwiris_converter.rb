require 'byebug'

module Moodle2AA::Learnosity::Converters::Wiris
  class ShortAnswerWirisConverter < WirisConverter

    register_converter_type 'shortanswerwiris'

    def convert_question(moodle_question)
      question = Moodle2AA::Learnosity::Models::Question.new
      question.reference = generate_unique_identifier_for(moodle_question.id, '_question')

      data = question.data

      data[:stimulus] = convert_question_text(moodle_question)
      data[:is_math] = has_math?(data[:stimulus])
      data[:case_sensitive] = moodle_question.casesensitive
      question.type = data[:type] = "clozeformulaV2"

      validation = data[:validation] = {}
      validation[:alt_responses] = []

      data[:metadata] = {}
      rationale = data[:metadata][:distractor_rationale_response_level] = []

      data[:metadata].merge!(convert_feedback( moodle_question ))
      data[:is_math] ||= has_math?(data[:metadata])

      import_status = IMPORT_STATUS_COMPLETE
      todo = []

      validation[:scoring_type] = "exactMatch"

      tolerance = get_tolerance(moodle_question)

      moodle_question.answers.each do |answer|
        response = {score: answer.fraction.to_f}

        if moodle_question.has_compound_answer
          lines = answer.answer_text_plain.scan(/(.+)=(.+)$/)

          response[:value] = lines.map do |match|
            [{
              method: "equivValue",
              value: replace_wiris_variables(match[1]),
              options: tolerance
            }]
          end
        else
          response[:value] = [[{
            method: "equivValue",
            value: replace_wiris_variables(answer.answer_text_plain),
            options: tolerance
          }]]
        end

        rationale << convert_answer_feedback(answer)

        if answer.fraction.to_f == 1 && !validation[:valid_response]
          validation[:valid_response] = response
        elsif answer.fraction.to_f > 0
          validation[:alt_responses] << response
        end
      end

      data[:template] = convert_fomula_template(moodle_question, validation[:valid_response][:value].length)

      rationale.each { |feedback| data[:is_math] ||= has_math?(feedback) }
      question.scale_score(moodle_question.default_mark)
      set_penalty_options(question, moodle_question)
      add_instructor_stimulus(question, moodle_question)

      script, is_valid = generate_datatable_script(moodle_question)

      if !is_valid
        import_status = IMPORT_STATUS_PARTIAL
        todo << "Was unable to generate valid JS. Check Data table Script for best-attempt"
      end

      item = create_item(moodle_question: moodle_question,
                         import_status: import_status,
                         questions: [question],
                         todo: todo,
                         data_table_script: script)

      return item, [question]
    end

    def get_tolerance(moodle_question)
      return {} if moodle_question.tolerance.nil?

      if moodle_question.tolerance_digits
        {
          decimalPlaces: moodle_question.tolerance,
        }
      elsif moodle_question.relative_tolerance
        {
          tolerance: '\\percentage',
          tolerancePercent: moodle_question.tolerance * 100,
        }
      else
        {}
      end
    end

    def convert_fomula_template(question, num_responses)
      # I'm not sure why, but whether or not intial content is set is hit or mis
      if question.initial_content
        math_xml = Nokogiri::XML(question.initial_content).root

        return question.initial_content if math_xml.nil?

        lines = []
        line = ""

        math_xml.children.each do |child|
          if child.text == "="
            line << child.to_xml
            lines << "<math xmlns=\"http://www.w3.org/1998/Math/MathML\"> #{line} </math> {{response}}"
            line = ""
          else
            line << child.to_xml
          end
        end

        lines.join("<br>")
      elsif question.has_compound_answer
        math_xml = Nokogiri::XML(question.answers.first.answer_text).root
        replace_variables_in_math_ml(math_xml) { "{{response}}" }
      else
        return "{{response}}<br>" * num_responses if question.initial_content.nil?
      end

    end
  end
end
