# NOF - Network Operator Framework

```mermaid
graph TD;
  Controller["Controller"];
    Dashboard["Dashboard"];
    Executor["Executor"];

    Controller -->|update_data & acquire_config| Dashboard;
    Executor -->|acquire_tasks & report_results| Controller;
```

## Connectivity Requirements

The Controller needs to be able to reach the Dashboard to update data and acquire configuration changes. The Executor needs to be able to reach the Controller to acquire tasks. For a hybrid deployment the Dashboard needs
to be able to reach the remote Dashboard.