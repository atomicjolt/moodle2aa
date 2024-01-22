require 'json'

module Moodle2AA::Learnosity::Writers
  class Export

    def initialize(learnosity, moodle_course)
      @moodle_course = moodle_course
      @learnosity = learnosity
    end

    def create(out_dir)
      out_file = File.join(out_dir, filename)
      Dir.mktmpdir do |dir|
        write_cartridge(dir)

        tmp_file = File.join(dir, filename)
        zip_dir(tmp_file, dir)
        FileUtils.mv(tmp_file, out_file)
      end
      out_file
    end

    def write_cartridge(dir)
        json = create_json
        File.open(dir+"/export.json","w") do |f|
          f.write(json)
        end
        filewriter = FileMetaWriter.new(dir,@learnosity.files)
        filewriter.write
    end

    def create_json
      JSON.generate(@learnosity)
    end
    
    def filename
      title = @moodle_course.fullname.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
        gsub(/([a-z\d])([A-Z])/, '\1_\2').
        gsub(/[\/|\.]/, '_').
        tr('- ', '_').downcase.
        gsub(/_{2,}/, '_')
      "#{title}-learnosity.zip"
    end

    private

    def zip_dir(out_file, dir)
      Zip::File.open(out_file, Zip::File::CREATE) do |zipfile|
        Dir["#{dir}/**/*"].each do |file|
          zipfile.add(file.sub(dir + '/', ''), file)
        end
      end
    end

  end
end
