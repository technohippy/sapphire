require "test/unit"
require "sapphire"

class TestSapphire < Test::Unit::TestCase
  def test_convert_string
    assert_equal '1 + 1', Sapphire.convert_string('1 + 1')
  end
end
