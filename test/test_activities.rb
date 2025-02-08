class TestActivities < Minitest::Test
  def test_add
    Activities.add(action: "test")
    assert_equal 1, Activities.size
  end

  def test_register
    Activities.register("test_register") do
      "test"
    end
    assert_equal "test", Activities.own_actions["test_register"].call
    assert_equal "test", Activities.test_register
  end
end