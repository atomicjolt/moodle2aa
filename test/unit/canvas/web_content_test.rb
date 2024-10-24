require 'nokogiri'
require 'minitest/autorun'
require 'test_helper'
require 'moodle2aa'

class TestUnitCanvasWebContent < MiniTest::Test
  include TestHelper

  def setup
    convert_moodle_backup 'canvas'
    @mod = @backup.course.mods.find { |m| m.mod_type == "resource" && m.type == "html" }
  end

  def teardown
    clean_tmp_folder
  end

  def test_it_inherits_from_cc
    assert Moodle2AA::Canvas::WebContent.ancestors.include?(Moodle2AA::CC::WebContent), 'does not inherit from base CC class'
  end

  def test_it_creates_item_in_module_meta
    web_content = Moodle2AA::Canvas::WebContent.new @mod
    node = Builder::XmlMarkup.new
    xml = Nokogiri::XML(web_content.create_module_meta_item_node(node, 5))

    assert_equal 'item', xml.root.name
    assert_equal 'i6f06dd1384233e65fa28bd11b97c8b16', xml.root.attributes['identifier'].value
    assert_equal "Instructor Resources", xml.root.xpath('title').text
    assert_equal '5', xml.root.xpath('position').text
    assert_equal '', xml.root.xpath('new_tab').text
    assert_equal '1', xml.root.xpath('indent').text
    assert_equal 'WikiPage', xml.root.xpath('content_type').text
    assert_equal 'i6447ff05ab6e342a42302007a6e3bcb4', xml.root.xpath('identifierref').text
  end

  def test_it_creates_web_content_item_from_link_with_summary
    mod = @backup.course.mods.find { |m| m.mod_type == "resource" &&
        (!m.summary.nil? && m.summary.length != 0)}
    mod.type = 'file'
    web_content = Moodle2AA::Canvas::WebContent.new mod

    assert web_content.body.include?(mod.reference)
    assert web_content.body.include?(mod.summary)
  end
end
