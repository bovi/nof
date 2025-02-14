class TestTask < Minitest::Test
  def setup
    init_model_db
  end
  
  def teardown
    delete_model_db
  end

  def test_add
    s = Tasks.size
    Tasks.add(uuid: "123e4567-e89b-12d3-a456-426614174000",
              host_uuid: "456e4567-e89b-12d3-a456-426614174000",
              tasktemplate_uuid: "789e4567-e89b-12d3-a456-426614174000")
    assert_equal s + 1, Tasks.size, "Task should be added"

    t = Tasks["123e4567-e89b-12d3-a456-426614174000"]
    assert_equal "123e4567-e89b-12d3-a456-426614174000", t[:uuid]
    assert_equal "456e4567-e89b-12d3-a456-426614174000", t[:host_uuid]
    assert_equal "789e4567-e89b-12d3-a456-426614174000", t[:tasktemplate_uuid]

    Tasks.delete("123e4567-e89b-12d3-a456-426614174000")
    assert_equal s, Tasks.size, "Task should be deleted"
  end

  def test_activities_add_delete
    s = Tasks.size
    sa = Activities.size

    # create task
    # check if activity and task was created
    activity_uuid, task = Activities.task_add(host_uuid: "456e4567-e89b-12d3-a456-426614174000",
                                              tasktemplate_uuid: "789e4567-e89b-12d3-a456-426614174000")
    assert_equal s + 1, Tasks.size, "Task should be created"
    assert_equal sa + 1, Activities.size, "Activity should be created"
    assert_equal "task_add", Activities[activity_uuid][:action]
    assert_equal "456e4567-e89b-12d3-a456-426614174000", Activities[activity_uuid][:opt][:host_uuid]
    assert_equal "789e4567-e89b-12d3-a456-426614174000", Activities[activity_uuid][:opt][:tasktemplate_uuid]

    # delete task
    # check if task was deleted and activity was created
    activity_uuid, result = Activities.task_delete(uuid: task[:uuid])
    assert_equal s, Tasks.size, "Task should be deleted"
    assert_equal sa + 2, Activities.size, "2. Activity should be created"
    assert_equal "task_delete", Activities[activity_uuid][:action]
    assert_equal task[:uuid], Activities[activity_uuid][:opt][:uuid]
  end
end