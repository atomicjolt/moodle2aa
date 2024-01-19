require 'minitest/autorun'
require 'test_helper'
require 'moodle2aa'

class TestUnitMoodleBackup < MiniTest::Test
  include TestHelper

  def setup
    @moodle_backup_path = create_moodle_backup_zip
  end

  def teardown
    clean_tmp_folder
  end

  def test_it_has_info
    backup = Moodle2AA::Moodle::Backup.read @moodle_backup_path
    assert_instance_of Moodle2AA::Moodle::Info, backup.info
  end

  def test_it_has_a_course
    backup = Moodle2AA::Moodle::Backup.read @moodle_backup_path
    assert_instance_of Moodle2AA::Moodle::Course, backup.course
  end

  def test_it_has_files
    backup = Moodle2AA::Moodle::Backup.read @moodle_backup_path
    assert_equal ["folder/test.txt", "test.txt"], backup.files
  end
end
