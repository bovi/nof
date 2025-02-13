# Models for NOF

Models are used to manage data. They are also integrated into the Activity system.
The activity system is used to sync data between systems. In the model we not
only need to handle the data model but also register the activities for syncing.

## Inherit

All models inherit from `Model`.

```
class MyModel < Model
  # ...
end
```

## Setup

A model needs to handle the setup of it's own tables.

```
class MyModel < Model
  class << self
    def setup_tables
      create_table('my_model', [
        'id',
        'name'
      ])
    end
  end
end
```

## Activities Registration

If a certain model action should be synced to another system, it needs to be registered.

```
class MyModel < Model
  class << self
    def my_action(uuid)

      # ...

      # return a hash which can be used to call the registered action again
      {uuid: uuid}
    end
  end
end

Activities.register("my_model_action") do |hsh|
  MyModel.my_action(hsh[:uuid])
end
```

The action needs to return a hash which can be feed again into the registered action.
The hash will be used to call the registered action again.

## The Activity Model

The activity model is special. It is used by other models to register their actions.
A registration implements the logic how to handle the data of a model. During the operation 
each system is only allowed to call model actions via the registered Activity model actions.
In this way all changes in the system can be tracked and synced to other systems.

```
class MyModel < Model
  class << self
    def my_action(uuid)
      # ...
    end
  end
end

Activities.register("my_model_action") do |hsh|
  MyModel.my_action(hsh[:uuid])
end

# !!! NOT LIKE THIS! THIS WON'T BE SYNCED !!!
MyModel.my_action(uuid)

# this is the correct way to call the action
Activities.my_model_action(uuid: uuid)
```