module Moodle2AA::Moodle
  class Info
    include HappyMapper

    tag 'INFO'
    element :name, String, :tag => 'NAME'
  end
end
