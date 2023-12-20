module Moodle2CC
  module Learnosity::Converters::ConverterHelper
    
    # Migration status values, for "Migration status" tag
    IMPORT_STATUS_TAG_TYPE = "Import status"
    IMPORT_STATUS_BAD = "Incomplete"
    IMPORT_STATUS_PARTIAL = "Needs review"
    IMPORT_STATUS_COMPLETE = "Complete"
    IMPORT_STATUS_MANUAL = "Manual"

    MIGRATION_STATUS_TAG_TYPE = "Migration status"
    MIGRATION_STATUS_INITIAL = "Not started"
    
    MOODLE_QUESTION_TYPE_TAG_TYPE = "Moodle question type"
    CATEGORY_TAG_TYPE = "category"



    def generate_unique_resource_path(base_path, readable_name, file_extension = 'html')
      file_name_suffix = readable_name ? Moodle2CC::CanvasCC::Models::Page.convert_name_to_url(readable_name) : ''
      ext = file_extension ? ".#{file_extension}" : ''
      File.join(base_path, generate_unique_identifier(), "#{file_name_suffix}#{ext}")
    end

    def generate_unique_identifier_for(id, suffix = nil)
      # Trying to fix 252 mess..  version with a _1
      # also 352 and 203
      if @moodle_course.url == 'https://extension.moodle.wisc.edu/prod' && [65,83,109].include?(@moodle_course.course_id.to_i)
        version = "_1"
      else
        version = ''
      end
      unique_id = Digest::MD5.hexdigest(@moodle_course.url + id.to_s + suffix)
      unique_id = unique_id.gsub(/^(.{8})(.{4})(.{4})(.{4})(.{12})$/, '\1-\2-\3-\4-\5')
#     id_set = Moodle2Converter::Migrator.unique_id_set
#     if id_set.include?(unique_id)
#       # i was under the impression that moodle ids would be unique themselves
#       # but i have been apparently misinformed
#       original_id = unique_id
#       index = 0
#       while id_set.include?(unique_id)
#         index += 1
#         unique_id = "#{original_id}#{index}"
#       end
#     end
#     id_set << unique_id
      unique_id += version
      unique_id
    end

    def convert_text(text,format)
      text ||= ''
      text = RDiscount.new(text).to_html if format.to_i == 4 # markdown
      convert_latex text
    end

    def convert_latex(text)
      text.gsub(/\$\$(.*?)\$\$/, '\\(\1\\)')
    end

    def truncate_text(text, max_length = nil, ellipsis = '...')
      max_length ||= MAX_TITLE_LENGTH
      return text if !text || text.length <= max_length

      actual_length = max_length - ellipsis.length

      # First truncate the text down to the bytes max, then lop off any invalid
      # unicode characters at the end.
      truncated = text[0,actual_length][/.{0,#{actual_length}}/mu]
      truncated + ellipsis
    end

    LEARNING = Moodle2CC::MigrationReport::LEARNING
    TEACHING = Moodle2CC::MigrationReport::TEACHING
    OTHER = Moodle2CC::MigrationReport::OTHER

    def report_add_warn(model, edulevel, message, url=nil, name=nil)
      if !name && model.respond_to?(:name)
        name = 'learnosity-'+model.name
      end
      if !url && model.respond_to?(:module_id)
        mod = model.class.to_s.downcase.gsub(/^.*::/, '')
        url = "mod/#{mod}/view.php?id=#{model.module_id}"
      end
      Moodle2CC::MigrationReport.add(model, edulevel, message, url, name)
    end

    def report_current_course_id()
      Moodle2CC::MigrationReport.moodle_course_id
    end

    # Check if an html string is non-empty
    def html_non_empty?(text)
      text = text || ''
      (text.gsub(%r{</?[^>]+?>},'') =~ /[[:graph:]]/) || text =~ /img/
    end

    # get single tag for category
    def get_tag_for_category(category, categories, recursive)
      cats = get_parent_categories(category, categories) 
      format_category_tag(cats, recursive)
    end 

    # get all tags for questions in a category.  Includes the category tag,
    # along with any needed by recursive random questions.
    def get_tags_for_category(category, categories)
      cats = get_parent_categories(category, categories) 
      # join into a single tag
      tags = [format_category_tag(cats, false)]
      # look for any recursive random questions
      needs_extra_tag = false
      cats.each_index do |index|
        cat = cats[index]
        needs_extra_tag = cat.questions.find { |q| q.type == "random" && q.question_text == "1" }
        if needs_extra_tag
          tags << format_category_tag(cats[0,index+1], true)
        end
      end
      is_random_category = needs_extra_tag || category.questions.find { |q| q.type == "random" }
      return tags, is_random_category
    end 

    def format_category_tag(cats, recursive)
      # remove "default for" components
      catnames = cats.map{|c| c.name}
      out = catnames.join("/").gsub(/^Default for /,"")
      out += " and subcategories" if recursive
      out
    end

    # find all parent categories
    def get_parent_categories(category, categories)
      cats = []
      used = []
      tcategory = category
      begin
        cats << tcategory
        break if used.include? tcategory.id # prevent loops, an occasional moodle problem
        used << tcategory.id
        tcategory = categories.find { |cat| cat.id == tcategory.parent }
      end while tcategory
      cats.reverse
    end

    # import status for item containing questions of status a and b
    def import_status_combine(a, b)
      if a == IMPORT_STATUS_MANUAL || b == IMPORT_STATUS_MANUAL
        IMPORT_STATUS_MANUAL
      elsif a == IMPORT_STATUS_BAD || b == IMPORT_STATUS_BAD
        IMPORT_STATUS_BAD
      elsif a == IMPORT_STATUS_PARTIAL || b == IMPORT_STATUS_PARTIAL
        IMPORT_STATUS_PARTIAL
      else
        IMPORT_STATUS_COMPLETE
      end
    end

  end
end
