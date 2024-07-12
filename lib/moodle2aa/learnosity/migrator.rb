module Moodle2AA::Learnosity
  class Migrator

    VERSION = "2018.11.12"

    include Converters::ConverterHelper

    def initialize(output_dir)
      @output_dir = output_dir
    end

    def migrate(moodle_course)
      filter_random_questions(moodle_course)
      if Moodle2AA::MigrationReport.group_by_quiz_page?
         moodle_course = group_by_quiz_page(moodle_course)
      else
         moodle_course = group_synchronized_questions(moodle_course)
      end

      learnosity = create_learnosity_export(moodle_course)
      learnosity.files = convert_files(moodle_course)
      html_converter = Moodle2AA::Learnosity::Converters::HtmlConverter.new(learnosity.files, moodle_course)
      learnosity.meta = create_learnosity_export_meta(moodle_course)
      learnosity.items, learnosity.features, learnosity.questions = convert_questions(moodle_course.question_categories, moodle_course, html_converter)
      learnosity.activities += convert_assignments(moodle_course.quizzes, moodle_course)
      fix_assignment_tags(learnosity.activities, learnosity.items)
      convert_html!(learnosity, moodle_course)
      learnosity.files = remove_unused_files(learnosity.files)
      filter_items!(learnosity)
      @path = Moodle2AA::Learnosity::Writers::AtomicAssessments.new(learnosity, moodle_course).create(@output_dir) if Moodle2AA::MigrationReport.generate_archive?
    end

    private

    def create_learnosity_export(moodle_course)
      learnosity = Moodle2AA::Learnosity::Models::Export.new
      learnosity
    end

    def create_learnosity_export_meta(moodle_course)
      meta = Moodle2AA::Learnosity::Models::ExportMeta.new
      meta.moodle_url = moodle_course.url+'/course/view.php?id='+(moodle_course.course_id||'')
      meta.moodle_course_name = moodle_course.fullname
      meta.convert_date = Time.now.iso8601
      meta.version = VERSION
      meta
    end

    def clone_moodle_course(moodle_course_in)
      # clone everything we might change
      moodle_course = moodle_course_in.clone
      moodle_course.question_categories = moodle_course.question_categories.map {|cat| clone_moodle_question_category(cat)}
      moodle_course.quizzes = moodle_course.quizzes.map {|quiz| clone_moodle_quiz(quiz)}
      moodle_course
    end

    def clone_moodle_question_category(moodle_cat_in)
      # we may add questions to a category
      moodle_cat = moodle_cat_in.clone
      moodle_cat.questions = moodle_cat.questions.clone
      moodle_cat
    end

    def clone_moodle_quiz(moodle_quiz_in)
      # we may add and delete question instances
      moodle_quiz = moodle_quiz_in.clone
      moodle_quiz.question_instances = moodle_quiz.question_instances.clone
      moodle_quiz
    end

    # remove random questions not used in a quiz
    # we don't want special categories created for these
    def filter_random_questions(moodle_course)
      used = []
      moodle_course.quizzes.each do |qz|
        used += qz.question_instances.map {|q| q[:question]}
      end
      moodle_course.question_categories.each do |category|
        category.questions.select! do |q|
          if q.qtype != 'random' || used.include?(q.id)
            true
          else
            #print "Excluding random question #{q.name}\n"
            false
          end
        end
      end
    end

    def group_by_quiz_page(moodle_course)

      # semi-deep clone of the course since we'll be changing it
      moodle_course = clone_moodle_course(moodle_course)

      # extract all questions
      questions = []
      question_categories = {}
      moodle_course.question_categories.each do |category|
        category.questions.each do |question|
          questions << question
          question_categories[question.id] = category.id
        end
      end

      # process each quiz
      moodle_course.quizzes.each do |quiz|

        quizcat = Moodle2AA::Moodle2::Models::Quizzes::QuestionCategory.new
        quizcat.name = "#{quiz.name}"
        quizcat.id = "quiz-#{quiz.id}"
        quizcat.parent = 0
        moodle_course.question_categories << quizcat

        question_pages = []
        quiz.question_instances.each do |ref|
          question = questions.detect{|q| q.id.to_s == ref[:question]}
          next if !question
          page = ref[:page].to_i
          question_pages[page] ||= []
          question_pages[page] << question
        end

        # consolidate each group into a single new question
        new_question_instances = []
        (1..(question_pages.count-1)).each do |page|
          next if !question_pages[page]
          non_randoms = question_pages[page].select {|q| q.type != 'random'}
          if non_randoms.count > 0
            new_question = consolidate_quiz_page(question_pages[page], quiz, page)
            ref = {:question => new_question.id,
                   :grade => 1, # Doesn't matter for quizpage
                   :page =>page}
            new_question_instances << ref
            quizcat.questions << new_question
          end
          randoms = question_pages[page].select {|q| q.type == 'random'}
          randoms.each do |question|
            ref = quiz.question_instances.find {|i| i[:question] == question.id.to_s}
            abort "No instance?" if !ref
            ref[:learnosity_added] = true
            new_question_instances << ref
          end
        end
        quiz.question_instances = new_question_instances
      end
      moodle_course
    end

    def group_synchronized_questions(moodle_course)

      # semi-deep clone of the course since we'll be changing it
      moodle_course = clone_moodle_course(moodle_course)

      # extract all synchronized questions
      questions = []
      question_categories = {}
      moodle_course.question_categories.each do |category|
        category.questions.each do |question|
          next if !is_synchronized_question?(question)
          questions << question
          question_categories[question.id] = category.id
        end
      end

      # process each quiz
      moodle_course.quizzes.each do |quiz|
        # find groups of synchronized questions
        question_groups = {}
        quiz.question_instances.each do |ref|
          question = questions.detect{|q| q.id.to_s == ref[:question]}
          next if !question
          category = question_categories[question.id]
          question_groups[category] = question_groups[category] || []
          question_groups[category] << question
        end

        # consolidate each group into a single new question
        new_question_instances = []
        quiz.question_instances.each do |ref|
          question = questions.detect{|q| q.id.to_s == ref[:question]}
          if !question
            # not synchronized, just add to new array
            new_question_instances << ref
            next
          end

          category = question_categories[question.id]
          if !question_groups[category]
            # already consolidated, so skip
            next
          end

          if question_groups[category].size == 1
            # only one question in the group, just add to new array
            new_question_instances << ref
            next
          end

          #  It's the first time we saw this group, so consolidate questions and add to quiz and category.
          new_question = consolidate_shared_questions(question_groups[category], quiz)
          moodle_category = moodle_course.question_categories.find {|c| c.id == category}

          # See if we've already added this question group to the category.
          # This can happen if two quizzes have the same group.
          if !moodle_category.questions.detect {|q| q.id == new_question.id}
            moodle_category.questions << new_question
          end

          question_groups[category] = nil
          ref = ref.clone
          ref[:question] = new_question.id
          new_question_instances << ref
        end
        quiz.question_instances = new_question_instances
      end
      moodle_course
    end

    def is_synchronized_question?(question)
      (question.qtype == 'calculated' ||
       question.qtype == 'calculatedformat' ||
       question.qtype == 'calculatedmulti') && question.synchronize
    end

    def consolidate_shared_questions(questions, moodle_quiz)
      new_question = Moodle2AA::Learnosity::Models::Moodle2::CalculatedQuestionGroup.new
      new_question.name = questions.first.name + ' - (combined with other synchronized questions)'
      new_question.questions = questions
      # make a synthetic id which is unique to the group
      new_question.id = (questions.map { |q| q.id }).join('-')

      # save question scores
      # This was an array before, which didn't make sense.  Now it's a hash.
      new_question.max_score = {}
      question_ids = questions.map {|q| q.id}
      moodle_quiz.question_instances.each do |instance|
        if question_ids.include? instance[:question]
          new_question.max_score[instance[:question]] = instance[:grade]
        end
      end
      new_question
    end

    def consolidate_quiz_page(questions, moodle_quiz, page)
      new_question = Moodle2AA::Learnosity::Models::Moodle2::QuizPageGroup.new
      new_question.name = moodle_quiz.name + " - page #{page}"
      new_question.questions = questions.select {|q| q.type != 'random'}
      # make a synthetic id which is unique to the group
      new_question.id = (questions.map { |q| q.id }).join('-') + '_quiz_'+moodle_quiz.id

      # save question scores
      new_question.max_score = {}
      question_ids = questions.map {|q| q.id}
      moodle_quiz.question_instances.each do |instance|
        if question_ids.include? instance[:question]
          new_question.max_score[instance[:question]] = instance[:grade]
        end
      end
      new_question
    end


    def convert_questions(question_categories, moodle_course, html_converter)
      Moodle2AA::Learnosity::Converters::QuestionBankConverter.new(moodle_course, html_converter).convert(question_categories)
    end

    def convert_assignments(quizzes, moodle_course)
      assignments = []
      quizzes.each do |quiz|
        # It's not clear why assignments is an array of 1-element arrays of objects, but that's how AJ implemented it
        assignments << [Moodle2AA::Learnosity::Converters::AssignmentConverter.new(moodle_course).convert(quiz, moodle_course.question_categories)]
      end
      assignments
    end

    def fix_assignment_tags(activities, items)
      activities.each do |activity|
        activity = activity[0] # AJ convention
        import_status = IMPORT_STATUS_COMPLETE
        activity.data.items.each do |itemref|
          item = items.find {|i| i.reference == itemref}
          import_status = import_status_combine(import_status, item.tags[IMPORT_STATUS_TAG_TYPE][0])
        end
        activity.tags[IMPORT_STATUS_TAG_TYPE] = [import_status]
      end
    end


    def convert_files(moodle_course)
      files = []
      moodle_course.files.each do |file|
        files << Moodle2AA::Learnosity::Converters::FileConverter.new(moodle_course).convert(file)
      end
      files
    end

    def remove_unused_files(learnosity_files)
      used = {}
      # remove unused and duplicate files
      out = learnosity_files.select do |f|
        if used[f.name]
          false
        else
          if f._usage_count > 0
            used[f.name] = true
            true
          else
            false
          end
        end
      end

      puts "Referenced #{out.count} out of #{learnosity_files.count} files."
      out
    end

    def convert_item_html!(item, html_converter)
    end

    def convert_question_html!(question, html_converter)
#     question.text = html_converter.convert(question.text)
#     question.comment = html_converter.convert(question.comment || '')
#     question.parts.each do |part|
#       part.choices.map! { |t| html_converter.convert(t) }
#       part.comments.map! { |t| html_converter.convert(t) }
#     end
#     question.text = question.text.gsub(/MAPLETA_PART_([0-9]+)/, '<\1>')
    end

    def convert_feature_html!(feature, html_converter)
    end

    def convert_html!(learnosity, moodle_course)
      html_converter = Moodle2AA::Learnosity::Converters::HtmlConverter.new(learnosity.files, moodle_course)

      learnosity.items.each do |item|
        convert_item_html!(item, html_converter)
      end
      learnosity.questions.each do |question|
        convert_question_html!(question, html_converter)
      end
      learnosity.features.each do |feature|
        convert_feature_html!(feature, html_converter)
      end
    end

    def filter_items!(learnosity)
      puts "Filtering items"
      puts "Currently including: #{learnosity.items.count} items and #{learnosity.questions.count} questions."
      item_references = learnosity.activities.flatten.map do |activity|
        activity.data.items
      end.flatten.to_set

      case Moodle2AA::MigrationReport.unused_question_mode
      when 'exclude'
        puts "Excluding unused items"

        learnosity.items.select! do |item|
          item_references.include?(item.reference)
        end

        question_references = learnosity.items.map do |item|
          item.questions.map(&:reference)
        end.flatten.to_set

        learnosity.questions.select! do |question|
          question_references.include?(question.reference)
        end
      when 'only'
        puts "Including only unused items"

        learnosity.items.reject! do |question|
          item_references.include?(question.reference)
        end

        question_references = learnosity.items.map do |item|
          item.questions.map(&:reference)
        end.flatten.to_set

        learnosity.questions.select! do |question|
          question_references.include?(question.reference)
        end

        # There won't be any activities left since we filter out all their items
        learnosity.activities = []
      when 'keep'
        puts "Keeping all items"
      end

      puts "Included #{learnosity.items.count} items and #{learnosity.questions.count} questions."
    end
  end
end
