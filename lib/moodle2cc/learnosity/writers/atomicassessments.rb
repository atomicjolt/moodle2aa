require 'json'

module Moodle2CC::Learnosity::Writers
  class AtomicAssessments

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
      File.open(dir+"/export.json","w") do |f|
        f.write('{"version":2.0}'+"\n")
      end
      Dir.mkdir(dir+'/activities')
      Dir.chdir(dir+'/activities') do
        write_objects(@learnosity.activities)
      end
      Dir.mkdir(dir+'/questions')
      Dir.chdir(dir+'/questions') do
        write_objects(@learnosity.questions)
      end
      Dir.mkdir(dir+'/features')
      Dir.chdir(dir+'/features') do
        write_objects(@learnosity.features)
      end
      Dir.mkdir(dir+'/items')
      Dir.chdir(dir+'/items') do
        write_objects(@learnosity.items)
      end

      filewriter = FileMetaWriter.new(dir,@learnosity.files)
      filewriter.write
    end

    def write_objects(objects)
      objects.each do |obj|
        obj = obj[0] if obj.kind_of?(Array)   # for activities
        filename = obj.reference.gsub(/[^a-zA-Z0-9-]/, '_')+'.json'
        File.open(filename,"w") do |f|
          f.write(create_json(obj))
        end
      end
    end

    def create_json(obj)
      JSON.generate(obj)
    end
    
    def filename
      source = File.basename Moodle2CC::MigrationReport.source
      source = source.gsub(/(\.zip|\.mbz)/,'')
      "#{source}-learnosity.zip"
      #title = @moodle_course.fullname.gsub(/::/, '/').
      #gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
      #gsub(/([a-z\d])([A-Z])/, '\1_\2').
      #gsub(/[\/|\.]/, '_').
      #tr('- ', '_').downcase.
      #gsub(/_{2,}/, '_')
      #"#{title}-learnosity.zip"
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
