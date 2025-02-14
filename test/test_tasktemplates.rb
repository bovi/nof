class TestTaskTemplates < Minitest::Test
  def setup
    init_model_db
  end

  def teardown
    delete_model_db
  end

  def test_add
    s = TaskTemplates.size
    TaskTemplates.add(uuid: "123e4567-e89b-12d3-a456-426614174000", type: "shell",
                      opts: {
                        cmd: "echo 'Hello, world!'",
                        format: {
                          pattern: "(\w+): (\d+)",
                          template: "{name}: {value}"
                        }
                      })
    assert_equal s + 1, TaskTemplates.size, "Task template should be created"

    t = TaskTemplates["123e4567-e89b-12d3-a456-426614174000"]
    assert_equal "123e4567-e89b-12d3-a456-426614174000", t[:uuid]
    assert_equal "shell", t[:type]
    assert_equal "echo 'Hello, world!'", t[:opts][:cmd]
    assert_equal "(\w+): (\d+)", t[:opts][:format][:pattern]
    assert_equal "{name}: {value}", t[:opts][:format][:template]

    TaskTemplates.delete("123e4567-e89b-12d3-a456-426614174000")
    assert_equal s, TaskTemplates.size, "Task template should be deleted"
  end

  def test_activities_add_delete
    s = TaskTemplates.size
    sa = Activities.size

    # create task template
    # check if activity and task was created
    activity_uuid, task = Activities.tasktemplate_add(type: "shell", opts: { cmd: "echo 'Hello, world!'" })
    assert_equal s + 1, TaskTemplates.size, "Task template should be created"
    assert_equal sa + 1, Activities.size, "Activity should be created"
    assert_equal "tasktemplate_add", Activities[activity_uuid][:action]
    assert_equal "shell", Activities[activity_uuid][:opt][:type]
    assert_equal "echo 'Hello, world!'", Activities[activity_uuid][:opt][:opts]["cmd"]

    # delete task template
    # check if task was deleted and activity was created
    activity_uuid, result = Activities.tasktemplate_delete(uuid: task[:uuid])
    assert_equal s, TaskTemplates.size, "Task template should be deleted"
    assert_equal sa + 2, Activities.size, "2. Activity should be created"
    assert_equal "tasktemplate_delete", Activities[activity_uuid][:action]
    assert_equal task[:uuid], Activities[activity_uuid][:opt][:uuid]
  end

  def test_delete_with_tasks
    h = Hosts.add(hostname: "localhost", ip: "127.0.0.1")
    tt = TaskTemplates.add(type: "shell", opts: {cmd: "echo 'Hello, world!'"})
    s = Tasks.size
    t = Tasks.add(host_uuid: h[:uuid], tasktemplate_uuid: tt[:uuid])
    assert_equal s + 1, Tasks.size
    TaskTemplates.delete(tt[:uuid])
    assert_equal s, Tasks.size
  end
end