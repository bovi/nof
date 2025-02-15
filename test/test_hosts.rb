class TestHosts < Minitest::Test
  def setup
    init_model_db
  end

  def teardown
    delete_model_db
  end
  
  def test_hosts_add
    s = Hosts.size
    h = Hosts.add('hostname' => "localhost", 'ip' => "127.0.0.1")
    assert_equal s + 1, Hosts.size
    assert_equal "localhost", h['hostname']
    assert_equal "127.0.0.1", h['ip']

    assert_equal "localhost", Hosts[h['uuid']]['hostname']
    assert_equal "127.0.0.1", Hosts[h['uuid']]['ip']
  end

  def test_hosts_delete
    s = Hosts.size
    s_expected = s + 1
    h = Hosts.add('hostname' => "localhost", 'ip' => "127.0.0.1")
    refute_nil Hosts[h['uuid']]
    assert_equal s_expected, Hosts.size
    Hosts.delete(h['uuid'])
    assert_equal s, Hosts.size
    assert_nil Hosts[h['uuid']]
  end

  def test_delete_with_tasks
    h = Hosts.add('hostname' => "localhost", 'ip' => "127.0.0.1")
    tt = TaskTemplates.add('type' => "shell", 'opts' => {'cmd' => "echo 'Hello, world!'",
                                                         'interval' => 1,
                                                         'pattern' => "(\w+): (\d+)",
                                                         'template' => "{name}: {value}"})
    s = Tasks.size
    t = Tasks.add('host_uuid' => h['uuid'], 'tasktemplate_uuid' => tt['uuid'])
    assert_equal s + 1, Tasks.size
    Hosts.delete(h['uuid'])
    assert_equal s, Tasks.size
  end
end
