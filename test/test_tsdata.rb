class TestTSData < Minitest::Test
  def setup
    TSData.setup_db
  end

  def teardown
    TSData.delete_db
  end

  def test_datapoints
    size = TSData.size
    dp = TSData.add(
        'job_uuid' => SecureRandom.uuid,
        'key' => 'avg_latency',
        'value' => 10,
        'timestamp' => Time.now.to_i
    )
    assert_equal size + 1, TSData.size
    all = TSData.all
    TSData.delete(all.first['id'])
    assert_equal size, TSData.size
  end

  def test_datapoints_range_selection
    size = TSData.size
    job_uuid = SecureRandom.uuid
    key = 'avg_latency'
    # start 7 days ago
    start_time = Time.now.to_i - (60 * 60 * 24 * 7)
    key_id = TSData.add_key(job_uuid, key)
    TSData.add_bulk(
      key_id,
      11000.times.map { |i|
        # add a datapoint for every minute
        {
          'value' => rand(100),
          'timestamp' => start_time + (i * 60)
        }
      }
    )
    assert_equal size + 11000, TSData.size, "All datapoints should be added"
    start_time = Time.now.to_i - (60 * 60 * 24 * 5)
    end_time = Time.now.to_i - (60 * 60 * 24 * 2)
    datapoints = TSData.range(job_uuid, key, start_time, end_time)

    # result should be 3 days of datapoints +/- 1min
    assert_operator (3 * 24 * 60) - 1, :<=, datapoints.size, "Should be 3 days of datapoints -1min"
    assert_operator (3 * 24 * 60) + 1, :>=, datapoints.size, "Should be 3 days of datapoints +1min"
  end
end