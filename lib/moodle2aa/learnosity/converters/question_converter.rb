require "byebug"

module Moodle2AA::Learnosity::Converters
  class QuestionConverter
    include ConverterHelper

    def initialize(moodle_course, html_converter)
      @moodle_course = moodle_course
      @html_converter = html_converter
    end

    @@subclasses = {}
    def self.register_converter_type(name)
      @@subclasses[name] = self
    end

    self.register_converter_type 'description'

    def convert(moodle_question)
      #try override first
      item, content = convert_from_override(moodle_question)
      if item
        return item, content
      end

      type = moodle_question.type
      if type && c = @@subclasses[type]
        item, content = c.new(@moodle_course, @html_converter).convert_question(moodle_question)
      else
        report_add_warn(moodle_question, LEARNING, "unknown_question_type=#{type}", "question/preview.php?id=#{moodle_question.id}&courseid=#{report_current_course_id}")
        puts "Unknown question type: #{type}"
        # Pretend it's a description question and convert
        # TODO: convert unknown question types to something
        #raise "Unknown converter type: #{type}" if !Moodle2AA::MigrationReport.convert_unknown_qtypes?
        item, content = self.convert_question_stub(moodle_question)
      end

      return item, content
    end

    def convert_question(moodle_question)
      feature = Moodle2AA::Learnosity::Models::Feature.new
      feature.type = feature.data[:type] = 'sharedpassage'
      feature.reference = generate_unique_identifier_for(moodle_question.id, '_question')
      feature.data[:content] = convert_question_text(moodle_question)
      feature.data[:is_math] = has_math?(feature.data[:content])
      #feature.original_identifier = moodle_question.id
      #feature.original_qtype = moodle_question.qtype
      #question.comment = moodle_question.general_feedback
      #question.name = moodle_question.name
      #question.text = convert_question_text(moodle_question)
      item = create_item(moodle_question: moodle_question,
                         title: moodle_question.name,
                         import_status: IMPORT_STATUS_COMPLETE,
                         features: [feature])
      return item, [feature]
    end

    def convert_question_stub(moodle_question, manual_conversion = false)
      question = Moodle2AA::Learnosity::Models::Question.new
      question.type = question.data[:type] = 'clozetext'
      question.reference = generate_unique_identifier_for(moodle_question.id, '_question')
      content = convert_question_text(moodle_question)
      if manual_conversion
        content += "\n<br/><br/><strong>This question requires manual conversion. (type=<em>#{moodle_question.qtype}</em>)</strong>"
      else
        content += "\n<br/><br/><strong>This question is a stub, as there is currently no conversion from <em>#{moodle_question.qtype}</em> to Learnosity.</strong>"
      end
      source = moodle_question_url(moodle_question)
      content += "<br/> Source: <a href=\"#{source}\" target=\"_blank\">#{source}</a>"
      name = moodle_question.name + ' (INCOMPLETE)'
      #feature.original_identifier = moodle_question.id
      #feature.original_qtype = moodle_question.qtype
      #question.comment = moodle_question.general_feedback
      #question.name = moodle_question.name
      #question.text = convert_question_text(moodle_question)

      answers = moodle_question.answers.map do |answer|
        label = convert_answer_text(answer)
        feedback = convert_answer_feedback(answer)
        feedback = " Feedback: #{feedback}" if feedback.length > 0
        "<li>#{label} (#{answer.fraction.to_f.round(3)} pts) #{feedback}</li>"
      end
      if answers.count > 0
        content += "<h4>Answers (in Moodle internal format)<\h4>\n<ul>\n #{answers.join("\n")}\n</ul>"
      end
      question.data[:stimulus] = content
      question.data[:template] = ''
      question.data[:validation] = {scoring_type: "exactMatch", valid_respnse: { score: 1, value: [] }}
      question.data[:is_math] = has_math?(question.data[:stimulus])
      set_penalty_options(question, moodle_question)
      add_instructor_stimulus(question, moodle_question)
      item = create_item(moodle_question: moodle_question,
                         title: name,
                         import_status: manual_conversion ? IMPORT_STATUS_MANUAL : IMPORT_STATUS_BAD,
                         questions: [question])
      return item, [question]
    end

    def create_item(moodle_question: ,
                    title: nil,
                    import_status: ,
                    notes: [],
                    todo: [],
                    features: [],
                    questions: [],
                    content: [],
                    extra_tags: [],
                    dynamic_content_data: nil,
                    data_table_script: nil)

      item = Moodle2AA::Learnosity::Models::Item.new

      item.reference = generate_unique_identifier_for(moodle_question.id, '_item')
      item.status = 'published'
      item.source = moodle_question_url(moodle_question)
      item.metadata ||= {}
      item.metadata[:moodle_question_id] = moodle_question.id

      title = title || moodle_question.name
      max_length = [149, title.length].min
      item.title = title[0..max_length]
      item.tags[MIGRATION_STATUS_TAG_TYPE] = [MIGRATION_STATUS_INITIAL]
      item.tags[IMPORT_STATUS_TAG_TYPE] = [import_status]
      item.tags[MOODLE_QUESTION_TYPE_TAG_TYPE] = moodle_question_type_tag(moodle_question)

      extra_tags.each do |type, value|
        item.tags[type] ||= []
        item.tags[type] +=  value
      end

      if todo && todo.length > 0
        item.tags['TODO'] ||= []
        item.tags['TODO'] += todo
        item.tags['TODO'] = item.tags['TODO'].uniq
      end

      notes = notes.join("\n") if notes.is_a? Array
      item.note = notes

      unless dynamic_content_data.nil?
        item.definition.template = "dynamic"
        item.dynamic_content_data = dynamic_content_data
      end

      unless data_table_script.nil?
        item.definition.template = "dynamic"
        item.tags[DATA_TABLE_SCRIPT_TAG_TYPE] = [DATA_TABLE_SCRIPT_TAG_NAME]
        item.source = data_table_script
      end

      content += features
      content += questions
      content.each {|f| add_content_to_item(item, f)}

      item
    end

    def add_content_to_item(item, question_or_feature)
      ref = question_or_feature.reference_object
      if question_or_feature.is_a?(Moodle2AA::Learnosity::Models::Feature)
        item.features << ref
      else
        item.questions << ref
      end
      item.definition.widgets << {reference: ref.reference}
    end

    def moodle_question_url(moodle_question, preview=false)
      # For shared calculated quesitons, concatenate all urls
      if moodle_question.respond_to? :questions
        # compound type
        questions = moodle_question.questions
      else
        questions = [moodle_question]
      end

      if preview
        urls = questions.map {|q| "#{@moodle_course.url}/question/preview.php?id=#{q.id}&courseid=#{report_current_course_id}&behaviour=immediatefeedback" }
      else
        urls = questions.map {|q| "#{@moodle_course.url}/question/question.php?id=#{q.id}&courseid=#{report_current_course_id}" }
      end
      urls.join(',')
    end

    def moodle_question_type_tag(moodle_question)
      questions = [moodle_question]
      if moodle_question.respond_to? :questions
        # compound type
        questions += moodle_question.questions
      end
      (questions.map {|q| q.qtype}).uniq
    end

    def convert_latex(text)
      text.gsub(/\$\$(.*?)\$\$/, '\\(\1\\)')
    end

    def has_math?(obj)
      result = false
      if obj.is_a?(Hash) || obj.is_a?(Array)
        obj.each {|value| result ||= has_math? value}
      else
        result = (obj.to_s =~ /(\\\(|\\\[|<math|\$\$)/)? true:false
      end
      result
    end

    def strip_tags(html)
      Nokogiri::HTML.parse(html).text
    end

    def convert_question_text(moodle_question)
      material = moodle_question.question_text || ''
      material = RDiscount.new(material).to_html if moodle_question.question_text_format.to_i == 4 # markdown
      material = convert_latex material
      # strip mathjax cruft
      material = material.gsub(/<script.*?<\/script>/m, '')
      @html_converter.convert(material, 'question', 'questiontext', moodle_question.id)
    end

    def convert_answer_text(moodle_answer)
      material = moodle_answer.answer_text || ''
      material = RDiscount.new(material).to_html if moodle_answer.answer_format.to_i == 4 # markdown
      material = convert_latex material
      @html_converter.convert(material, 'question', 'answer', moodle_answer.id)
    end

    def convert_answer_feedback(moodle_answer)
      material = moodle_answer.feedback || ''
      material = RDiscount.new(material).to_html if moodle_answer.feedback_format.to_i == 4 # markdown
      material = convert_latex material
      material = @html_converter.convert(material, 'question', 'answerfeedback', moodle_answer.id)
      #material = '' if !html_non_empty?(material)
    end


    def convert_feedback(moodle_question)
      metadata = {}
      metadata[:correct_feedback] = ''
      metadata[:incorrect_feedback] = ''
      metadata[:partially_correct_feedback] = ''
      if moodle_question.respond_to? :correctfeedback
        metadata[:correct_feedback] = convert_other_feedback(
              moodle_question, moodle_question.correctfeedback, 'correctfeedback'
        )
      end
      if moodle_question.respond_to? :incorrectfeedback
        metadata[:incorrect_feedback] = convert_other_feedback(
              moodle_question, moodle_question.incorrectfeedback, 'incorrectfeedback'
        )
      end
      if moodle_question.respond_to? :partiallycorrectfeedback
        metadata[:partially_correct_feedback] = convert_other_feedback(
              moodle_question, moodle_question.partiallycorrectfeedback, 'partiallycorrectfeedback'
        )
      end
      # Which courses would benefit from hints?  Currently only ME340
      use_hints = @moodle_course.url == 'https://extension.moodle.wisc.edu/prod' && [97].include?(@moodle_course.course_id.to_i)
      if use_hints
        hints = moodle_question.hints.select do |hint|
          stripped = hint.delete("\n")
          stripped = stripped.gsub(/<[^>]*>/,'')
          stripped = stripped.gsub(/[[:space:]]|[.]|&nbsp;/,'')
          trivial = (stripped =~ /\A(|Tryagain)\Z/i)
          if !trivial
            puts "HINT '#{hint}' #{moodle_question.id}"
          end
          !trivial
        end
        hints = hints.map do |hint|
          convert_other_feedback(moodle_question, hint, 'hint')
        end
        if hints.count > 0
          metadata[:hints] = hints.uniq
        end
      end
      metadata[:general_feedback] = convert_general_feedback(moodle_question)
      metadata.delete_if {|key, value| value.is_a?(String)&& !html_non_empty?(value)}
      metadata
    end

    def convert_general_feedback(moodle_question)
      material = moodle_question.general_feedback || ''
      material = convert_latex material
      @html_converter.convert(material, 'question', 'generalfeedback', moodle_question.id)
    end

    def convert_other_feedback(moodle_question, feedback, file_area)
      material = feedback || ''
      material = convert_latex material
      @html_converter.convert(material, 'question', file_area, moodle_question.id)
    end

    def render_conversion_notes(notes)
      if !notes.kind_of?(Enumerable)
        return '' if notes == ''
        notes = [notes]
      end
      return '' if notes.count == 0

      #out = "<p>Conversion notes:</p>"
      out = ""
      notes.each do |note|
        out += "<br />\n#{note}\n"
      end
      out
    end

    def render_feedback_warning(answers)
      out = "<p>This question contains per-response feedback which was not converted:</p>"
      out += "<ul style=\"list-style-type: circle\">\n"
      answers.each do |answer|
        if html_non_empty?(answer.feedback)
          out += "<li>
          Student response: #{answer.answer_text}<br/>
          Grade: #{answer.fraction.to_f*100}%<br/>
          Feedback: <div style=\"margin-left: 40px;\">#{answer.feedback}</div>
          </li>"
        end
      end
      out += "</ul>"
      out
    end
    def render_expression_variables(expressions)
      return nil unless expressions.length > 0
      out = "<p>Expressions converted from Moodle:</p>"
      out += "<pre>\n"
      expressions.each_pair do |var, expr|
        out += CGI::escapeHTML(" #{var} := #{expr}\n")
      end
      out += "</pre>"
      out
    end

    def convert_from_override(moodle_question)
      oldreference = generate_unique_identifier_for(moodle_question.id, '_item')
      if oldreference.match(/.*_1$/)
        oldreference = oldreference[0..-3] # remove _1 version (ece 252)
      end
      qdata = Moodle2AA::Learnosity::Converters::Overrides.instance.get_override(oldreference)
      return nil,nil if !qdata
      # use the overrice
      print "Using existing question for #{moodle_question.name} (#{moodle_question.qtype})\n"
      question = Moodle2AA::Learnosity::Models::Question.new
      question.type = qdata["type"]
      question.data = qdata
      question.reference = generate_unique_identifier_for(moodle_question.id, '_question')
      question.scale_score(moodle_question.default_mark)
      set_penalty_options(question, moodle_question)
      #add_instructor_stimulus(question, moodle_question)
      item = create_item(moodle_question: moodle_question,
                         title: moodle_question.name,
                         import_status: IMPORT_STATUS_COMPLETE,
                         questions: [question])
      return item, [question]
    end

    def set_penalty_options(question, moodle_question)
      if moodle_question.penalty
        penalty = moodle_question.penalty.to_f * 100
        question.data[:metadata] ||= {}
        question.data[:metadata][:penalty_percent] = penalty.to_s
      end
      question.data[:feedback_attempts] = moodle_question.hints.count + 1
      question.data[:instant_feedback] = true
    end

    def add_instructor_stimulus(subcontent, moodle_question)
        subcontent = [subcontent] if !subcontent.is_a? Array
        subcontent[0].data[:instructor_stimulus] ||= ''
        url = moodle_question_url(moodle_question)
        previewurl = moodle_question_url(moodle_question, true)
        subcontent[0].data[:instructor_stimulus] = "
<h4>#{moodle_question.name}</h4>
<p>This question was automatically converted from Moodle</p>
<p>Moodle source: <a href='#{url}' target='_blank'>Edit</a> <a href='#{previewurl}' target='_blank'>Preview</a></p>
#{subcontent[0].data[:instructor_stimulus]}
"
    end

  end
end
