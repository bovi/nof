# Simple Task Distribution System

This system consists of three main components:

1. **Dashboard** (Port 8080): Web interface for task management and monitoring
2. **Controller** (Port 8081): Central task coordination server
3. **Executor** (Port 8082): Task execution agent

## Setup

1. Install Ruby (no additional dependencies required)

2. Start the components in separate terminals:
```bash
# Start Dashboard
ruby dash.rb

# Start Controller
ruby ctrl.rb

# Start Executor
ruby exec.rb
```

## Architecture

- Dashboard -> Controller: Task configuration and monitoring
- Controller -> Executor: Task distribution
- Executor -> Controller: Task result reporting

## Components

- `dash.rb`: Web interface for managing tasks and viewing results
- `ctrl.rb`: Central task coordination
- `exec.rb`: Task execution agent
- `lib/`: Shared utilities and models 