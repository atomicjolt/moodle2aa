module Moodle2CC::Learnosity::Converters
  class FileConverter
    include ConverterHelper
    
    def initialize(moodle_course)
      @moodle_course = moodle_course
    end

    def convert(moodle_file)
      learnosity_file = Moodle2CC::Learnosity::Models::LearnosityFile.new

      unique_id = moodle_file.content_hash
      # we probably shouldn't have been using these as identifiers but if we change it now we'll break updates on re-import

      # Does this apply for learnosity?
      #id_set = Migrator.unique_id_set
      #if id_set.include?(unique_id)
      #  original_id = unique_id
      #  index = 0
      #  while id_set.include?(unique_id)
      #    index += 1
      #    unique_id = "#{original_id}#{index}"
      #  end
      #end
      #id_set << unique_id

      learnosity_file.identifier = generate_unique_identifier_for(unique_id, '_file')
      learnosity_file.file_path = moodle_file.file_path + moodle_file.file_name
      learnosity_file.name = learnosity_file.identifier+File.extname(moodle_file.file_name)
      learnosity_file.mime_type = moodle_file.mime_type
      learnosity_file._file_location = moodle_file.file_location
      learnosity_file._component = moodle_file.component
      learnosity_file._file_area = moodle_file.file_area
      learnosity_file._item_id = moodle_file.item_id
      learnosity_file
    end

    private
  end
end
