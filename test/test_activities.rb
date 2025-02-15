class TestActivities < Minitest::Test
  def setup
    init_model_db
  end

  def teardown
    delete_model_db
  end

  def test_add
    sa = Activities.size
    Activities.add('action' => "test")
    assert_equal sa + 1, Activities.size
  end

  def test_register
    Activities.register("test_register") do
      "test"
    end
    r = Activities.own_actions["test_register"].call
    assert_equal "test", r
    uuid, result = Activities.test_register
    uuid_regxp = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
    assert_match(uuid_regxp, uuid)
    assert_equal "test", result
  end
end