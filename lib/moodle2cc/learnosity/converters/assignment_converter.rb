module Moodle2CC::Learnosity::Converters
  class AssignmentConverter
    include ConverterHelper

    def initialize(moodle_course)
      @moodle_course = moodle_course
    end

    def convert(moodle_quiz, question_categories)
      activity = Moodle2CC::Learnosity::Models::Activity.new
      activity.reference = get_reference(moodle_quiz)

      #activity.original_identifier = moodle_quiz.id
      activity.data.rendering_type = 'assess'
      activity.status = "published"
      activity.data.config.regions = "main"
      activity.data.config.navigation.show_intro = true
      activity.data.config.navigation.show_outro = true
      activity.data.config.title = moodle_quiz.name
      activity.title = moodle_quiz.name
      source = moodle_quiz_url(moodle_quiz)
      # TODO: handle quiz intro
      activity.data.items, question_random_usages = resolve_item_references(moodle_quiz.question_instances, question_categories, moodle_quiz)
      if moodle_quiz.question_instances.size > activity.data.items.size
        activity.tags[IMPORT_STATUS_TAG_TYPE] = [IMPORT_STATUS_BAD] # missing random questions
      else
        activity.tags[IMPORT_STATUS_TAG_TYPE] = [IMPORT_STATUS_PARTIAL]
      end
      
      activity.description = "Moodle source url: #{source}\n"
      if question_random_usages.count > 0
        activity.description += "\n\nRandomization parameters:\n"
        activity.description += (question_random_usages.map { |tag,count| "  #{tag} : #{count} question#{count>1?"s":""}\n"} ).join("\n")
      end

      activity
    end

    private
    
    def moodle_quiz_url(moodle_quiz)
      "#{@moodle_course.url}/mod/quiz/view.php?q=#{moodle_quiz.id}"
    end

    def resolve_item_references(question_instances, question_categories, moodle_quiz)
      all_question_ids = []
      question_instances.each do |ref|
        question, groupid = find_question(ref[:question], question_categories);
        all_question_ids << question.id
        if question.respond_to? :questions
          question.questions.each {|subq| all_question_ids << subq.id}
        end
      end
      item_references = []
      question_random_usages = {}
      variants = [] # questionids
      question_instances.each do |ref|
        max_score = ref[:max_score]
        question, groupid = find_question(ref[:question], question_categories);
        if question.type == 'random'
          # add all question variants to the quiz
          recurse = question.question_text == "1"
          cat = question_categories[groupid]
          tag = get_tag_for_category(cat, question_categories, recurse)
          if (question_random_usages[tag])
            # already saw this group, so increment the counter
            question_random_usages[tag] += 1
          else
            # find all related categories
            question_random_usages[tag] = 1
            # add all questions in cat
            newquestions = []
            newquestions += cat.questions.select {|q| q.qtype!='random' && q.qtype!='description'}
            #(cat.questions.select {|q| q.type!='random'}).each {|q| puts "#{moodle_quiz.name},#{q.qtype}"}
            if recurse 
              # find questions in child categories too
              catids = [cat.id]
              done = false
              while !done
                new_cats = question_categories.select { |c| catids.include?(c.parent) && !catids.include?(c.id) }
                # add all questions in new_cats
                if new_cats.count > 0
                  new_cats.each do |c| 
                    newquestions += c.questions.select {|q| q.qtype!='random' && q.qtype!='description'}
                    #(c.questions.select {|q| q.type!='random'}).each {|q| puts "#{moodle_quiz.name},#{q.qtype}"}
                  end
                  catids += new_cats.map { |c| c.id }
                else
                  done = true
                end
              end
              # add special tags unique to this recursive group.  Once random questions
              # work in learnosity, we'll configure the quiz to select from this group. 
              # TODO: generate unique tag for hierarchy
              # TODO: finish random questions
            else
              # non recursive case.  we can just use the existing category tag to select
            end

            newquestions.each do |q|
              # see if it's already there.  this does happen frequently and moodle handles it properly
              if all_question_ids.find {|sid| sid == q.id }
                puts "Random variant already in quiz: #{q.id}"
              else
                # update default mark.  This isn't really right, but learnosity
                # does question scoring differently than moodle, and this may work in many cases
                q.default_mark = max_score
                variants << q.id
              end
            end
          end
        else
          # non-random question
          variants = [question.id]
        end

        variants.each do |id|
          reference = generate_unique_identifier_for(id, '_item')
          item_references << reference
        end
      end
      return item_references.uniq, question_random_usages
    end

    def find_question(question_id, question_groups)
      question_groups.each_with_index do |group, groupid|
        question = group.questions.detect{|q| q.id == question_id}
        if question
          return [question, groupid]
        end
      end
      raise "Missing question: #{question_id}"
    end

    def get_reference(moodle_quiz)
      # Add the quiz name to the reference.  Eventually this won't be necessary,
      # but right now the authoring UI doesn't display the activity title on the
      # index list, only the reference
      reference = generate_unique_identifier_for(moodle_quiz.id, '_quiz')
      ascii_title = moodle_quiz.name.delete("^\u{0000}-\u{007F}'").delete("'\"`\n")[0..100]
      ascii_title.lstrip!  # AJ UI breaks if first character is a space
      ascii_title + ' -- ' + reference

    end
  end
end
