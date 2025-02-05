module NOF
  class Dashboard
    extend DatabaseConfig
    DEFAULT_PORT = 1080

    def self.setup_tables(db)
      db.execute(<<-SQL)
        CREATE TABLE IF NOT EXISTS dashboard_state (
          id INTEGER PRIMARY KEY,
          state TEXT NOT NULL
        )
      SQL
    end

    def self.state
      result = db.get_first_value("SELECT state FROM dashboard_state ORDER BY id DESC LIMIT 1")
      result ? result.to_sym : :unknown
    end

    def self.state=(_state)
      db.execute("INSERT INTO dashboard_state (state) VALUES (?)", [_state.to_s])
    end
  end
end