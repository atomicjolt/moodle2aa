module Moodle2AA::Learnosity::Converters
  class CalculatedConverter < QuestionConverter
    register_converter_type 'calculated'
    register_converter_type 'calculatedsimple'
    register_converter_type 'calculatedquestiongroup'
    register_converter_type 'calculatedformat'
    register_converter_type 'calculatedmulti'
    register_converter_type 'quizpage'

    RELATIVE_ERROR = 1
    NOMINAL_ERROR = 2
    GEOMETRIC_ERROR = 3

    def convert_question(moodle_question)
      expr_converter = ExpressionConverter.new(moodle_question, @moodle_course, @html_converter)
      if moodle_question.type == 'calculatedquestiongroup' ||
          moodle_question.type == 'quizpage'
        item, questions = convert_calculated_question_group(moodle_question, expr_converter)
      else
        item, questions = convert_calculated_question(moodle_question, expr_converter)
      end
      tofix=%w(
0177686e-1953-f244-7e7c-b9d135beea85_1
0d4d3cab-a6e4-9d8d-3197-56e6a2933aad_1
0e213808-b527-112c-25e0-87f3553982d5_1
155dd199-79af-6025-d305-498772f750b7_1
163291e3-5359-1124-cccd-6d6bdd451a74_1
25f4fa1d-9618-b4a3-1171-9a8e8300d5e3
2befbaa0-ddf8-ae98-27f4-38eff45e57dc_1
2bf0643a-0b79-6247-6d20-daac1807eabb
2d87b5ab-c615-5d3d-ccb2-1f933b11c9c8_1
31a5df38-53dd-4ed5-2fd8-8fd298001630_1
38c687c6-3fd2-3205-49f1-ecff208af6d5
3fb6036c-f2bb-fc4c-9b5d-042ceb3cc90f_1
40301d74-ef42-e83e-a545-2cf79fe01135_1
4293df1d-c9cf-5b15-d1fb-c2a6f0bde0b4
4600aeec-f188-33ed-0614-318925f5445a_1
69b325ea-bdd8-ed8d-81ba-5a2626492d13_1
75603947-21ee-486f-94eb-296b401825a5_1
846c88b6-032b-7f8e-32bb-5f0482c9e907_1
89bcc0cb-bcda-2135-75cf-0bd06745bc6e
8e59405c-2506-6ff6-0e4a-a3cd75937aad_1
8f57ac91-7bce-4556-1f1f-0e368a2431fe
9376363f-69d8-61b9-94c9-b718e125cb78
94f4424a-4685-ed30-8d48-dd3b0d0dcb38_1
96f0bc8f-4d2e-7985-1b93-2a2b50647104_1
96f7abb4-6163-da6b-32be-b4c975cf375e
976b4b2c-e57b-1c72-f06b-8148e423eafe
978458d0-d303-2eef-6128-3c985d99f68b_1
ab20d533-dc72-2e5f-b50b-2aea1dff4574_1
ae63b901-62cd-0014-a291-4fc284b13b91
b22f5819-e177-0a1d-b0de-854a0319e188_1
d23c9402-6e58-f49e-9374-a2452b4adcfc
de4ad4e9-52e9-3b38-e8c9-25d6ea22fbf3_1
ed8482fc-eedd-fe3f-ef44-ba32d77e5f57_1
      )
#      if tofix.include? item.reference 
#        dump = expr_converter.dump_csv
#        print "===START===\n"+@moodle_course.fullname+"\n"+item.reference+"  -  "+moodle_question.name+"\n"+dump+"\n===END===\n"
#      end

      return item, questions
    end

    def convert_calculated_question(moodle_question, expr_converter)
      reference = generate_unique_identifier_for(moodle_question.id, '_question')

      if moodle_question.qtype == "calculatedformat"
        question, import_status, todo = convert_calculated_format_subquestion(moodle_question, reference, expr_converter)
      elsif moodle_question.qtype == "calculatedmulti"
        question, import_status, todo = convert_calculated_multi_subquestion(moodle_question, reference, expr_converter)
      else
        question, import_status, todo = convert_calculated_subquestion(moodle_question, reference, expr_converter)
      end

      question.scale_score(moodle_question.default_mark)
      set_penalty_options(question, moodle_question)
      item = create_item(moodle_question: moodle_question, 
                         import_status: import_status,
                         questions: [question],
                         dynamic_content_data: expr_converter.generate_dynamic_content_data,
                         todo: todo)
      #if expr_converter.has_truncated_rows?
        #puts "TRUNCATED_DATASET: #{item.reference}: '#{moodle_question.name}'"
      #end
      return item, [question]
    end
    
    def convert_calculated_subquestion(moodle_question, reference, expr_converter)
      question = Moodle2AA::Learnosity::Models::Question.new
      question.reference = reference
      notes = []
      todo = []

      import_status = IMPORT_STATUS_COMPLETE

      data = question.data
      
      data[:stimulus] = convert_question_text moodle_question
      data[:stimulus] = convert_calculated_text data[:stimulus], expr_converter, moodle_question

      data[:instantfeedback] = true
      question.type = data[:type] = "formulaV2"
      data[:ui_style] = {type: "no-input-ui"}
      data[:is_math] = true
      
      validation = data[:validation] = {}
      validation[:scoring_type] = "exactMatch"
      validation[:alt_responses] = []
      
      correct_feedback = []
      incorrect_feedback = []
      numcorrect = 0
      moodle_question.all_answers.each do |answer|
        # TODO: numerical per-response feedback
        answer_text = convert_calculated_answer answer.answer_text, expr_converter, moodle_question
        options = moodle_question.all_options[answer.id.to_i]
        decimal_places = 10
        if options[:tolerance].to_f != 0
          case options[:tolerancetype].to_i
          when RELATIVE_ERROR 
            answer_text = "#{answer_text} \\pm #{options[:tolerance]}*(#{answer_text})"
          when NOMINAL_ERROR
            answer_text += " \\pm #{options[:tolerance]}"
          when GEOMETRIC_ERROR
            # Migration courses don't have any of these.  Convert as nominal
            answer_text += " \\pm #{options[:tolerance]}"
          end
        end
        value = [{method: "equivValue",
                  value: answer_text,
                  options: { decimalPlaces: decimal_places }
                }]
        response = {score: answer.fraction.to_f, value: value}
        if answer.fraction.to_f == 1 && !validation[:valid_response]
          # first right answer
          validation[:valid_response] = response
        elsif answer.fraction.to_f > 0
          # alternative answers
          validation[:alt_responses] << response
        end
        if answer.fraction.to_f == 1
          numcorrect += 1
        end
        feedback = convert_answer_feedback(answer)
        feedback = convert_calculated_text feedback, expr_converter, moodle_question
        if html_non_empty? feedback
          data[:is_math] ||= has_math?(feedback)
          if answer.fraction.to_f == 1
            correct_feedback << feedback
          else
            incorrect_feedback << feedback
          end
        end
      end

      data[:metadata].merge!(convert_feedback( moodle_question ))
      if data[:metadata][:general_feedback]
        data[:metadata][:general_feedback] = convert_calculated_text data[:metadata][:general_feedback], expr_converter, moodle_question
      end
      data[:is_math] ||= has_math?(data[:metadata])

      # try to handle feedback
      if numcorrect == 1 && correct_feedback.count == 1
        # easy case - add to general correct feedback
        data[:metadata][:correct_feedback] ||= ''
        data[:metadata][:correct_feedback] = correct_feedback[0] + "<br/>" + data[:metadata][:correct_feedback]
        correct_feedback.shift
      end

      if correct_feedback.count > 0 || incorrect_feedback.count > 0
        # Can't handle this, so add a conversion note to the instructor stimulus
        notes << render_feedback_warning(moodle_question.answers)
        todo << "Check per response feedback"
        import_status = IMPORT_STATUS_PARTIAL
      end
      
      if error = expr_converter.get_error
        import_status = IMPORT_STATUS_MANUAL
        todo << "Check formula error"
        notes << error
      end
      
      expressionnotes = render_expression_variables expr_converter.get_expression_variables
      if expressionnotes
        notes << expressionnotes
      end
      
      # add equestion information
      data[:instructor_stimulus] = render_conversion_notes(notes)

      return question, import_status, todo
    end

    def convert_calculated_format_subquestion(moodle_question, reference, expr_converter)
      question = Moodle2AA::Learnosity::Models::Question.new
      question.reference = reference
      notes = []
      todo = []
      
      import_status = IMPORT_STATUS_COMPLETE

      data = question.data
      
      data[:stimulus] = convert_question_text moodle_question
      data[:stimulus] = convert_calculated_text data[:stimulus], expr_converter, moodle_question

      data[:instantfeedback] = true

      question.type = data[:type] = "shorttext"
      data[:ui_style] = {type: "no-input-ui"}
      data[:is_math] = true
      
      validation = data[:validation] = {}
      validation[:scoring_type] = "exactMatch"
      validation[:alt_responses] = []

      #if moodle_question.calculatedformat_options[:exactdigits] != '1'
        #import_status = IMPORT_STATUS_PARTIAL
        #notes << "Question may allow answers of varying length, for example with or without leading zeros.  Short answer conversion doesn't allow this."
      #end
        
      correct_feedback = []
      incorrect_feedback = []
      numcorrect = 0
      moodle_question.all_answers.each do |answer|
        # TODO: numerical per-response feedback
        answer_texts = convert_calculated_format_answer answer.answer_text, expr_converter, moodle_question
        answer_texts.each do |answer_text|
          options = moodle_question.all_options[answer.id.to_i]
          decimal_places = 10
          if options[:tolerance].to_f != 0
            # Not handled
            notes << "Question has an answer error tolerance, which isn't compatible with short answer.  If the tolerance is critical, convert to a math question type."
            todo << "Check calculated answer tolerance"
            import_status = IMPORT_STATUS_PARTIAL
          end
          response = {score: answer.fraction.to_f, value: answer_text}
          if answer.fraction.to_f == 1 && !validation[:valid_response]
            # first right answer
            validation[:valid_response] = response
          elsif answer.fraction.to_f > 0
            # alternative answers
            validation[:alt_responses] << response
          end
        end
        if answer.fraction.to_f == 1
          numcorrect += 1
        end
        feedback = convert_answer_feedback(answer)
        feedback = convert_calculated_text feedback, expr_converter, moodle_question
        if html_non_empty? feedback
          data[:is_math] ||= has_math?(feedback)
          if answer.fraction.to_f == 1
            correct_feedback << feedback
          else
            incorrect_feedback << feedback
          end
        end
      end
      
      data[:metadata].merge!(convert_feedback( moodle_question ))
      if data[:metadata][:general_feedback]
        data[:metadata][:general_feedback] = convert_calculated_text data[:metadata][:general_feedback], expr_converter, moodle_question
      end
      data[:is_math] ||= has_math?(data[:metadata])

      # try to handle feedback
      if numcorrect == 1 && correct_feedback.count == 1
        # easy case - add to general correct feedback
        data[:metadata][:correct_feedback] = correct_feedback[0] + "<br/>" + data[:metadata][:correct_feedback]
        correct_feedback.shift
      end

      if correct_feedback.count > 0 || incorrect_feedback.count > 0
        # Can't handle this, so add a conversion note to the instructor stimulus
        notes << render_feedback_warning(moodle_question.answers)
        todo << "Check per response feedback"
        import_status = IMPORT_STATUS_PARTIAL
      end
      
      if error = expr_converter.get_error
        import_status = IMPORT_STATUS_MANUAL
        todo << "Check formula error"
        notes << error
      end

      # add equestion information
      expressionnotes = render_expression_variables expr_converter.get_expression_variables
      if expressionnotes
        notes << expressionnotes
      end
      

      data[:instructor_stimulus] = render_conversion_notes(notes)

      return question, import_status, todo
    end
    
    def convert_calculated_multi_subquestion(moodle_question, reference, expr_converter)
      question = Moodle2AA::Learnosity::Models::Question.new
      question.reference = reference
      notes = []
      todo = []

      import_status = IMPORT_STATUS_PARTIAL

      data = question.data
      
      data[:stimulus] = convert_question_text moodle_question
      data[:stimulus] = convert_calculated_text data[:stimulus], expr_converter, moodle_question

      data[:instantfeedback] = true
      question.type = data[:type] = "mcq"
      
      data[:multiple_responses] = !moodle_question.single
      data[:ui_style] = {type: "horizontal"}

      data[:is_math] = true
      
      validation = data[:validation] = {}
      validation[:scoring_type] = "exactMatch"
      validation[:alt_responses] = []
      data[:shuffle_options] = moodle_question.shuffleanswers

      options = data[:options] = []
      
      data[:metadata] = {}
      rationale = data[:metadata][:distractor_rationale_response_level] = []

      value = 0;
      moodle_question.all_answers.each do |answer|
        ans_options = moodle_question.all_options[answer.id.to_i]
        # TODO: expression digits, sig figs
        answer_text = convert_answer_text answer
        answer_text = convert_calculated_text answer_text, expr_converter, moodle_question
        options << {label: answer_text,
                    value: value.to_s}
        feedback = convert_answer_feedback(answer)
        feedback = convert_calculated_text feedback, expr_converter, moodle_question
        rationale << feedback
        if moodle_question.single
          # single select
          validation[:scoring_type] = "exactMatch"
          response = {score: answer.fraction.to_f, value: [value.to_s]}
          if answer.fraction.to_f == 1 && !validation[:valid_response]
            validation[:valid_response] = response
          elsif answer.fraction.to_f > 0
            validation[:alt_responses] << response
          end
        else
          # multiple select
          # per-item custom response weighting is dropped.  There's nothing we
          # can really do about that.  Instead we go with uniform positive scores
          # for correct answers and negative penalty for incorrect answers.
          validation[:scoring_type] = "partialMatchV2"
          validation[:penalty] = 1
          validation[:rounding] = "none"
          validation[:valid_response] ||= {score: 1, value: []}
          if answer.fraction.to_f > 0
            validation[:valid_response][:value] << value.to_s
          end
        end
        value += 1
      end
      options.each { |option| data[:is_math] ||= has_math?(option[:label]) }
      rationale.each { |feedback| data[:is_math] ||= has_math?(feedback) }
      
      data[:metadata].merge!(convert_feedback( moodle_question ))
      if data[:metadata][:general_feedback]
        data[:metadata][:general_feedback] = convert_calculated_text data[:metadata][:general_feedback], expr_converter, moodle_question
      end
      if data[:metadata][:correct_feedback]
        data[:metadata][:correct_feedback] = convert_calculated_text data[:metadata][:correct_feedback], expr_converter, moodle_question
      end
      if data[:metadata][:incorrect_feedback]
        data[:metadata][:incorrect_feedback] = convert_calculated_text data[:metadata][:incorrect_feedback], expr_converter, moodle_question
      end
      if data[:metadata][:partially_correct_feedback]
        data[:metadata][:partially_correct_feedback] = convert_calculated_text data[:metadata][:partially_correct_feedback], expr_converter, moodle_question
      end
      data[:is_math] ||= has_math?(data[:metadata])

      if error = expr_converter.get_error
        import_status = IMPORT_STATUS_MANUAL
        notes << error
        todo << "Check formula error"
      end
      
      expressionnotes = render_expression_variables expr_converter.get_expression_variables
      if expressionnotes
        notes << expressionnotes
      end
      
      # add equestion information
      data[:instructor_stimulus] = render_conversion_notes(notes)

      return question, import_status, todo
    end

    def convert_calculated_question_group(moodle_question, expr_converter)
      content = []
      todo = []
      group_import_status = IMPORT_STATUS_COMPLETE
      moodle_question.questions.each do |subquestion|
        #binding.pry if subquestion.id.to_i == 51006
        if subquestion.qtype == "calculatedformat"
          reference = generate_unique_identifier_for("#{moodle_question.id}+#{subquestion.id}", '_question')
          question, import_status, newtodo = convert_calculated_format_subquestion(subquestion, reference, expr_converter)
          question.scale_score(moodle_question.max_score[subquestion.id])
          add_instructor_stimulus(question, subquestion)
          subcontent = [question]
        elsif subquestion.qtype == "calculated" ||
              subquestion.qtype == "calculatedsimple"
          reference = generate_unique_identifier_for("#{moodle_question.id}+#{subquestion.id}", '_question')
          question, import_status, newtodo = convert_calculated_subquestion(subquestion, reference, expr_converter)
          question.scale_score(moodle_question.max_score[subquestion.id])
          add_instructor_stimulus(question, subquestion)
          subcontent = [question]
        elsif subquestion.qtype == "calculatedmulti"
          reference = generate_unique_identifier_for("#{moodle_question.id}+#{subquestion.id}", '_question')
          question, import_status, newtodo = convert_calculated_multi_subquestion(subquestion, reference, expr_converter)
          question.scale_score(moodle_question.max_score[subquestion.id])
          add_instructor_stimulus(question, subquestion)
          subcontent = [question]
        else
          # any other question type
          subitem, subcontent = convert(subquestion)
          import_status = subitem.tags[IMPORT_STATUS_TAG_TYPE][0]
          newtodo = subitem.tags['TODO'] || []
          cnt = 0
          subcontent.each do |content|
            reference = generate_unique_identifier_for("#{moodle_question.id}+#{subquestion.id}+'_'+#{cnt}", '_question')
            content.reference = reference
            cnt += 1
          end
          subcontent.each {|question| question.scale_score(moodle_question.max_score[subquestion.id])}
        end
        content += subcontent
        todo += newtodo
        group_import_status = import_status_combine(group_import_status, import_status)
      end

      extra_tags = {}
      if expr_converter.has_shuffled_vars?
        extra_tags['TODO'] = ['Check merged datatable']
      end
      item = create_item(moodle_question: moodle_question, 
                         import_status: group_import_status,
                         content: content,
                         extra_tags: extra_tags,
                         dynamic_content_data: expr_converter.generate_dynamic_content_data,
                         todo: todo)
      
      #if expr_converter.has_truncated_rows?
        #puts "TRUNCATED_DATASET: #{item.reference}: '#{moodle_question.name}'"
      #end
      return item, content, todo
    end


    # Convert text with embedded variables and expressions 
    def convert_calculated_text(text, expr_converter, moodle_question)
      substitute_embedded_expressions(text, expr_converter, moodle_question)
    end
    
    # Convert answer text
    def convert_calculated_answer(text, expr_converter, moodle_question)
      as_expr, as_var = expr_converter.convert_answer(text, nil, moodle_question)
      as_var # use the variable by default
    end
    
    def convert_calculated_format_answer(text, expr_converter, moodle_question)
      out = []
      opts = moodle_question.calculatedformat_options
      use_prefix = opts[:correctanswershowbase] == '1'
      lengthint = opts[:correctanswerlengthint]
      lengthfrac = opts[:correctanswerlengthfrac]

      base = case opts[:correctanswerbase]
             when '2'
               'b'
             when '8'
               'o'
             when '16'
               'x'
             when '10'
               'd'
             else
               raise "Unknown base"
             end
      separator = case opts[:correctanswergroudigits]
                  when '3'
                    ','
                  when '4'
                    '_'
                  else
                    ''
                  end
      
      format = "%"+separator+lengthint+'.'+lengthfrac+base
      as_expr, as_var = expr_converter.convert_answer(text, format, moodle_question)

      prefix = "0"+base
      # primary answer is with or without prefix, depending on use_prefix
      if use_prefix
        out = [prefix+as_var, as_var]
      else
        out = [as_var, prefix+as_var]
      end
      out
    end

    def substitute_variables(text, expr_converter, moodle_question)
      text.gsub(/\{([^%{}=]+)\}/) do |match|
        _, as_var = expr_converter.convert_expression match, moodle_question
        as_var
      end
    end

    # Replace embedded expressions of the form {=...}
    def substitute_embedded_expressions(text, expr_converter, moodle_question)
      # replace {=...} expressions
      text = text.gsub(/\{(%[^=]+)?=([^{}]*(?:\{[^{}]+\}[^{}]*)*)\}/) do |match|
        _, as_var = expr_converter.convert_expression match, moodle_question
        as_var
      end
      # replace variables
      text = text.gsub(/\{[a-zA-Z0-9_-]*\}/) do |match|
        _, as_var = expr_converter.convert_expression match, moodle_question
        as_var
      end
      text
    end

    def has_multiple_answers?(moodle_question)
      moodle_question.answers.count > 1
    end

  end
end
