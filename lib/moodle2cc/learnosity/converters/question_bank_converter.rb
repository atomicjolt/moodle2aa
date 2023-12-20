module Moodle2CC::Learnosity::Converters
  class QuestionBankConverter
    include ConverterHelper

    def initialize(moodle_course, html_converter)
      @moodle_course = moodle_course
      @html_converter = html_converter
    end

    def convert(categories)
      questions = []
      features = []
      questions = []
      items = []

      question_converter = Moodle2CC::Learnosity::Converters::QuestionConverter.new(@moodle_course, @html_converter)
      
      # add category information to random questions
      categories.each do |category|
        category.questions.each do |moodle_question|
          if moodle_question.qtype == 'random'
            cats = get_parent_categories(category, categories) 
            is_recursive = moodle_question.question_text == '1'
            moodle_question.category_name = format_category_tag(cats, is_recursive)
          end
          moodle_question.category_id = category.id
        end
      end
      
      group_by_quiz_page = Moodle2CC::MigrationReport.group_by_quiz_page?

      # index all questions
      question_lookup = {}
      categories.each do |category|
        category.questions.each do |question|
          question_lookup[question.id.to_i] = question
        end
      end

      # determine which questions are used in quizzes
      used_in_quiz = {}
      @moodle_course.quizzes.each do |quiz|
        quiz.question_instances.each do |ref|
          next if ref[:learnosity_added]
          used_in_quiz[ref[:question].to_i] = true
          question = question_lookup[ref[:question].to_i]
          if question.qtype == 'quizpage'
            question.questions.each do |subquestion|
              used_in_quiz[subquestion.id.to_i] = true
            end
          end
        end
      end

      categories.each do |category|

        tags, cat_random_variant = get_tags_for_category(category, categories)

        category.questions.each do |moodle_question|
          if moodle_question.qtype == 'random'
            next
          end
          used = used_in_quiz[moodle_question.id.to_i]

          is_random_variant = cat_random_variant && (moodle_question.qtype != 'random' &&
                                                     moodle_question.qtype != 'description')

          item, content = question_converter.convert(moodle_question)

          item.tags['Moodle flag'] ||= []
          if used
            item.tags['Moodle flag'] << 'Used in a quiz explicitely'
          end
          if is_random_variant
            item.tags['Moodle flag'] << 'Used in a quiz as random variant'
          end
          if !is_random_variant && !used
            item.tags['Moodle flag'] << 'Not used in any quiz'
          end

          if used && !is_random_variant && moodle_question.qtype != 'quizpage'
            item.tags['Moodle flag'] << 'Duplicate, already included in a bundled item and not a random variant'
          end


          if item
            item.tags[CATEGORY_TAG_TYPE] = tags 
            items << item
          end

          content.each do |question_or_feature|
            if question_or_feature.is_a?(Moodle2CC::Learnosity::Models::Feature)
              features << question_or_feature
            else
              questions << question_or_feature
            end
          end
        end
      end

      return items, features, questions
    end
  end
end
