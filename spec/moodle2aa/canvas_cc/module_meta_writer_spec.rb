require 'spec_helper'

module Moodle2AA::CanvasCC
  describe ModuleMetaWriter do

    let(:canvas_module) { Models::CanvasModule.new }
    let(:module_item) { Models::ModuleItem.new }
    let(:tmpdir) { Dir.mktmpdir }

    before :each do
      Dir.mkdir(File.join(tmpdir, CartridgeCreator::COURSE_SETTINGS_DIR))
    end

    after :each do
      FileUtils.rm_r tmpdir
    end

    it 'should have a valid schema' do
      canvas_module.identifier = 'module_identifier'
      canvas_module.title = 'test_title'
      canvas_module.workflow_state = 'active'
      xml = write_xml(canvas_module)

      assert_xml_schema(xml)
    end

    it 'writes out modules correctly' do
      canvas_module.identifier = 'ident'
      canvas_module.title = 'module title'
      canvas_module.workflow_state = 'active'
      xml = write_xml(canvas_module)

      expect(xml.at_xpath('xmlns:modules/xmlns:module/@identifier').text).to eq('ident')
      expect(xml.%('modules/module/title').text).to eq('module title')
      expect(xml.%('modules/module/workflow_state').text).to eq('active')
      expect(xml.%('modules/module/position').text).to eq('0')
    end

    it 'increments the position for each module that is written' do
      xml = write_xml(Models::CanvasModule.new, Models::CanvasModule.new)
      expect(xml.%('modules/module/position').text).to eq('0')
      expect(xml.%('modules/module[last()]/position').text).to eq('1')
    end

    context 'module items' do
      it 'writes out module items correctly' do
        module_item.identifier = "some_unique_hash"
        module_item.content_type = "ContentType"
        module_item.workflow_state = "active"
        module_item.title = "Item Title"
        module_item.new_tab = nil
        module_item.indent = "1"
        module_item.url = 'http://example.com'

        module_item.identifierref = 'resource_id'

        canvas_module.module_items << module_item

        xml = write_xml(canvas_module)

        item_node = xml.%('modules/module/items/item')
        expect(item_node.at_xpath('@identifier').text).to eq('some_unique_hash')
        expect(item_node.%('content_type').text).to eq('ContentType')
        expect(item_node.%('workflow_state').text).to eq('active')
        expect(item_node.%('title').text).to eq('Item Title')
        expect(item_node.%('position').text).to eq('0')
        expect(item_node.%('new_tab')).to be_nil
        expect(item_node.%('indent').text).to eq('1')
        expect(item_node.%('identifierref').text).to eq('resource_id')
        expect(item_node.%('url').text).to eq('http://example.com')
      end

      it 'does not write the identifierref if it is not provided' do
        canvas_module.module_items << module_item

        xml = write_xml(canvas_module)

        expect(xml.%('modules/module/items/item/identifierref')).to be_nil
      end

      it 'does not write the url if it is not provided' do
        canvas_module.module_items << module_item

        xml = write_xml(canvas_module)

        expect(xml.%('modules/module/items/item/url')).to be_nil
      end

      it 'increments the position for each module item that is written in a module' do
        canvas_module.module_items << Models::ModuleItem.new
        canvas_module.module_items << Models::ModuleItem.new

        xml = write_xml(canvas_module)

        expect(xml.%('modules/module/items/item/position').text).to eq('0')
        expect(xml.%('modules/module/items/item[last()]/position').text).to eq('1')
      end
    end

    private

    def write_xml(*mod)
      writer = ModuleMetaWriter.new(tmpdir, *mod)
      writer.write
      path = File.join(tmpdir,
                       CartridgeCreator::COURSE_SETTINGS_DIR,
                       ModuleMetaWriter::MODULE_META_FILE)
      Nokogiri::XML(File.read(path))
    end

    def assert_xml_schema(xml)
      valid_schema = File.read(fixture_path(File.join('common_cartridge', 'schema', 'cccv1p0.xsd')))
      xsd = Nokogiri::XML::Schema(valid_schema)
      expect(xsd.validate(xml)).to be_empty
    end

  end
end