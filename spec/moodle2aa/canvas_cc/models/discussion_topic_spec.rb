require 'spec_helper'

module Moodle2AA::CanvasCC::Models
  describe DiscussionTopic do
    it_behaves_like 'it has an attribute for', :text
  end
end