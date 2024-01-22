module Moodle2AA::Learnosity::Models::JsonWriter

  def to_json(*a)
    hash = {}
    self.instance_variables.each do |v|
      hash[v[1..-1]] = self.instance_variable_get v if v[1] != "_"
    end
    hash.to_json(*a)
  end

end
