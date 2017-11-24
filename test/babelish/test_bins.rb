require 'test_helper'
class TestBins < Test::Unit::TestCase

  def test_csv2strings_with_config_file
    system("cp .babelish.sample .babelish")

    assert_nothing_raised NameError do
      system("./bin/babelish csv2strings")
    end
    assert_equal 0, $?.exitstatus
  end

  def teardown
    system("rm -f .babelish")
  end
end
