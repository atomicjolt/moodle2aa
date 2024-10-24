module Moodle2AA::Moodle2Converter
  class DiscussionConverter
    include ConverterHelper


    def convert(forum)
      discussion = Moodle2AA::CanvasCC::Models::Discussion.new
      discussion.identifier = generate_unique_identifier_for_activity(forum)
      discussion.title = truncate_text(forum.name)
      discussion.text = forum.intro
      discussion.is_announcement = forum.force_subscribe
      discussion.discussion_type = 'threaded'
      discussion.workflow_state = workflow_state(forum.visible)
      discussion.require_initial_post = (forum.type == 'qanda')

      points = forum.points_possible.to_i
      discussion.points_possible = points if points > 0

      discussion
    end

  end
end