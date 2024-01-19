module Moodle2AA::Learnosity::Writers
  class FileMetaWriter

    ASSETS_DIR = "assets"

    def initialize(work_dir, learnosity_files)
      @work_dir = work_dir
      @learnosity_files = learnosity_files
    end

    def write
      FileUtils.mkdir_p(File.join(@work_dir, ASSETS_DIR))
      copy_files
    end

    private

    def copy_files
      @learnosity_files.each do |learnosity_file|
        FileUtils.cp(learnosity_file._file_location, File.join(@work_dir, ASSETS_DIR, learnosity_file.name))
      end
    end
  end
end
