module Moodle2AA::Learnosity::Converters
  class EssayConverter < QuestionConverter
    register_converter_type 'essay'

    def convert_question(moodle_question)

      questions = []
      question = Moodle2AA::Learnosity::Models::Question.new
      question.reference = generate_unique_identifier_for(moodle_question.id, '_question')

      data = question.data

      data[:stimulus] = convert_question_text moodle_question

      if html_non_empty? moodle_question.responsetemplate
        data[:stimulus] += "
        <p> <strong><em>Please copy the following template into the response area before answering the question</em></strong></p>
        <div style=\"margin: 20px;\">
          #{moodle_question.responsetemplate}
        </div>
       "
      end
      data[:is_math] = has_math?(data[:stimulus])
      case moodle_question.responseformat
      when 'editor'
        question.type = data[:type] = "longtextV2"
      when 'editorfilepicker'
        question.type = data[:type] = "longtextV2"
      when 'plain'
        question.type = data[:type] = "plaintext"
      when 'monospaced'
        question.type = data[:type] = "plaintext"
      when 'noinline'
        question.type = data[:type] = "plaintext"
        # actually we'll remove the essay component later
      end
      data['show_word_limit'] = "off"
      data['show_word_count'] = false

      data['ui_style'] = { 
        min_height: "#{moodle_question.responsefieldlines.to_i*20}px"  # ~ 20 px per line
      }
      data[:validation] = {
        max_score: 1
      }
      data[:metadata] = {}
      graderinfo = moodle_question.graderinfo || ''
      graderinfo = convert_latex graderinfo
      graderinfo = @html_converter.convert(graderinfo, 'qtype_essay', 'graderinfo', moodle_question.id)
      data[:instructor_stimulus] = graderinfo
      data[:is_math] ||= has_math?(data[:instructor_stimulus])

      data[:metadata].merge!(convert_feedback( moodle_question ))
      data[:is_math] ||= has_math?(data[:metadata])

      question.scale_score(moodle_question.default_mark)
      questions << question
      
      if moodle_question.attachments.to_i != 0
        # add file upload question
        question = Moodle2AA::Learnosity::Models::Question.new
        question.reference = generate_unique_identifier_for(moodle_question.id, '_question_fileupload')

        data = question.data

        data[:stimulus] = ""
        data[:max_files] = moodle_question.attachments.to_i
        if data[:max_files] == -1
          data[:max_files] = 10   # unlimited = 10
        end
        question.type = data[:type] = "fileupload"
        # we're limited in what we can use
        data[:allow_pdf] = true
        data[:allow_jpg] = true
        data[:allow_gif] = true
        data[:allow_png] = true
        data[:allow_csv] = true
        data[:allow_rtf] = true
        data[:allow_txt] = true
        data[:allow_ms_word] = true
        data[:allow_ms_excel] = true
        data[:allow_open_office] = true
        
        data[:validation] = {
          max_score: 0  # I guess let the essay component have the score
        }

        questions << question
      end
      
      if moodle_question.responseformat == "noinline" && questions.count == 2
        # noinline means no essay, so copy the important parts
        # and remove the essay
        
        upload = questions[1]
        essay = questions[0]

        upload.data[:validation] = essay.data[:validation]
        upload.data[:metadata] = essay.data[:metadata]
        upload.data[:instructor_stimulus] = essay.data[:instructor_stimulus]
        upload.data[:stimulus] = essay.data[:stimulus]
        questions = [upload]
      end

      # no penalties / multiple tries
      #set_penalty_options(question, moodle_question)
      questions.each {|question| add_instructor_stimulus(question, moodle_question) }
      item = create_item(moodle_question: moodle_question, 
                         import_status: IMPORT_STATUS_COMPLETE,
                         questions: questions)
      return item, questions
    end
  end
end
