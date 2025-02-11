class TestTaskTemplates < Minitest::Test
  def setup
    init_model_db
  end

  def teardown
    delete_model_db
  end

  def test_add
    s = TaskTemplates.size
    TaskTemplates.add(uuid: "123", cmd: "echo 'Hello, world!'", type: "shell",
                      format: { pattern: "(\w+): (\d+)", template: "{name}: {value}" })
    assert_equal s + 1, TaskTemplates.size, "Task template should be created"

    t = TaskTemplates.get("123")
    assert_equal "123", t[:uuid]
    assert_equal "shell", t[:type]
    assert_equal "echo 'Hello, world!'", t[:cmd]
    assert_equal "(\w+): (\d+)", t[:format][:pattern]
    assert_equal "{name}: {value}", t[:format][:template]

    TaskTemplates.delete("123")
    assert_equal s, TaskTemplates.size, "Task template should be deleted"
  end

  def test_activities_add_delete
    s = TaskTemplates.size
    sa = Activities.size

    # create task template
    # check if activity and task was created
    activity_uuid, task = Activities.tasktemplate_add(cmd: "echo 'Hello, world!'", type: "shell")
    assert_equal s + 1, TaskTemplates.size, "Task template should be created"
    assert_equal sa + 1, Activities.size, "Activity should be created"
    assert_equal "tasktemplate_add", Activities[activity_uuid][:action]
    assert_equal "shell", Activities[activity_uuid][:opt][:type]
    assert_equal "echo 'Hello, world!'", Activities[activity_uuid][:opt][:cmd]

    # delete task template
    # check if task was deleted and activity was created
    activity_uuid, result = Activities.tasktemplate_delete(uuid: task[:uuid])
    assert_equal s, TaskTemplates.size, "Task template should be deleted"
    assert_equal sa + 2, Activities.size, "2. Activity should be created"
    assert_equal "tasktemplate_delete", Activities[activity_uuid][:action]
    assert_equal task[:uuid], Activities[activity_uuid][:opt][:uuid]
  end
end
