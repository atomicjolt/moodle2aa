module Moodle2AA::Learnosity::Models
  class Reference
    include JsonWriter

    attr_accessor :reference

    def initialize(ob)
      if ob.class == String
        @reference = ob
      else
        @reference = ob.reference
      end
    end
  end
end

