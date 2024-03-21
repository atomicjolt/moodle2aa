module Moodle2AA::Learnosity::Converters
  class HtmlConverter
    include ConverterHelper

    WEB_CONTENT_TOKEN = "__BASE_URI__"

    def initialize(learnosity_files, moodle_course)
      @moodle_course = moodle_course
      @learnosity_files = learnosity_files
    end

    def convert(content, component, file_area, item_id)
      content = update_links(content.gsub('id="main"', ''), component, file_area, item_id)
      content = convert_equations(content)
      content = fix_unicode(content)
      content = fix_html(content)
      content
    end

    private

    def fix_unicode(content)
      # these break json parsing, and MapleTA doesn't escape them properly
      #content = content.tr("\u000A\u000D\u2028\u2029", '    ');
      # @ characters are special in MapleTA, so convert to literals.
      #content = content.gsub("@", '&#64;');
      content
    end

    def fix_html(content)
      # learnosity converts font-weight: bold to a nested <strong>, which messes up
      # table formatting in ece 252
      content = content.gsub(/(<td[^>]*)font-weight:\s*bold/, "\\1font-weight: 700")
      # remove text-align on tables, as it breaks the WYSIWYG editor
      content = content.gsub(/(<table[^>]*)text-align:\s*[a-z]+\s*;?/, "\\1")

      content = content.gsub(/^<p>(.*)<\/p>$/m) do |match|
        # if no other p tags, strip the outer to match learnosity convention
        inner = $1
        if inner.match('<p>')
          match
        else
          inner
        end
      end

      # convert mathml
      lb = "\u00AB"
      rb = "\u00BB"
      quote = "\u00A8"
      singlequote = "\u0060"
      amp = "\u00A7"
      re = /  <math[^>]*>.+?<\/math>
            | #{lb}math[^#{rb}]*#{rb}.+?#{lb}\/math#{rb}
           /xm
      content = content.gsub(re) do |match|
        match.to_s.tr("#{lb}#{rb}#{quote}#{singlequote}#{amp}", "<>\"'&")
      end

      # convert latex
      latexre = /<tex(?:\s+alt=["\'](?<e>.*?)["\'])?>(.+?)<\/tex>|\$\$(?<e>.+?)\$\$|\[tex\](?<e>.+?)\[\/tex\]/m
      content = content.gsub(latexre) do | match|
        latex=$~[:e]
        latex = latex.tr("\n"," ")
        latex = latex.gsub(/\\\((.*?)\\\)/, "\\text{\\1}")

        '\\('+latex+'\\)'
      end

      # fix mathml empty elements so learnosity doesn't strip them
      content = content.gsub(/<mrow><\/mrow>/, "<mrow> <\/mrow>")
    end

    def update_links(content, component, file_area, item_id)
      html = Nokogiri::HTML.fragment(content)
      html.css('img[src]').each { |img| img['src'] = update_url(img.attr('src'), component, file_area, item_id) }
      html.css('a[href]').each { |a| a['href'] = update_url(a.attr('href'), component, file_area, item_id) }
      # html.css('a[href]').each do |tag|
      #   tag['href'] = update_url(tag.attr('href'))
      # end
      # html.css('link[href]').each { |tag| tag.remove }
      html.to_s
    end

    def update_url(link, component, file_area, item_id)
      if canvas_link = lookup_cc_file(link, component, file_area, item_id)
        canvas_link
      else
        link
      end
    rescue => e
      puts "invalid url #{link} - #{e.message}"
      link
    end

    def lookup_cc_file(link, component, file_area, item_id)
      if match = link.match(/@@PLUGINFILE@@(.*)/)
        file_link(match.captures.first, component, file_area, item_id) || link
      elsif match = link.match(/[$]IMS_CC_FILEBASE[$]\/(.*)/)
        # legacy file (moodle 1.9)
        file_link(match.captures.first, 'course', 'legacy') || link
      end
    end

    def file_link(moodle_path, component=nil, file_area=nil, item_id=nil)
      moodle_path = CGI::unescape(URI(moodle_path).path)
      cc_file = @learnosity_files.find do |file|
        result = moodle_path == file.file_path
        if component
          result &= component == file._component
        end
        if file_area
          result &= file_area == file._file_area
        end
        if item_id
          result &= item_id == file._item_id
        end
        result
      end
      if cc_file
        cc_file._usage_count += 1
        "#{WEB_CONTENT_TOKEN}#{cc_file.name}"
      else
        warn "No match for file #{moodle_path}, #{component}, #{file_area}, #{item_id}"
      end
    rescue => e
      puts "invalid url #{moodle_path} - #{e.message}"
    end

    def convert_equations(content)
      # turn moodle equations ( e.g. $$3 * x$$ ) into canvas equations
      # content.gsub(/\$\$([^\$]*)\$\$/) do |match|
      #   latex = $1.to_s.gsub("\"", "\\\"")
      #   if latex.length > 0
      #     url = "/equation_images/#{CGI.escape(CGI.escape(latex).gsub("+", "%20"))}"

      #     "<img class=\"equation_image\" title=\"#{latex}\" alt=\"#{latex}\" src=\"#{url}\">"
      #   else
      #     ""
      #   end
      #end
      content
    end
  end
end
