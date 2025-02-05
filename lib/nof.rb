require 'securerandom'
require 'json'

require_relative 'nof/version'
require_relative 'nof/logging'
require_relative 'nof/database_config'
require_relative 'nof/response_helper'

# Models
require_relative 'nof/dashboard'
require_relative 'nof/controller'
require_relative 'nof/executor'
require_relative 'nof/models/tasks'
require_relative 'nof/models/task_templates'
require_relative 'nof/models/groups'
require_relative 'nof/models/hosts'
require_relative 'nof/models/activities'

# Activity Handlers
require_relative 'nof/activity_handlers/base'
require_relative 'nof/activity_handlers/task_template_handler'
require_relative 'nof/activity_handlers/host_handler'
require_relative 'nof/activity_handlers/group_handler'

module NOF
  # Any module-level configuration can go here
end


# Create top-level constants for backward compatibility
Dashboard = NOF::Dashboard
Controller = NOF::Controller
Executor = NOF::Executor
Tasks = NOF::Tasks
TaskTemplates = NOF::TaskTemplates
Groups = NOF::Groups
Hosts = NOF::Hosts
Activities = NOF::Activities
ResponseHelper = NOF::ResponseHelper
DatabaseConfig = NOF::DatabaseConfig