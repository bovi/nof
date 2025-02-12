require 'tmpdir'

class TestDB < Minitest::Test
  def create_database(&block)
    @temp_dir = Dir.mktmpdir
    @db_file = File.join(@temp_dir, "test.db")
    @db = Database.new(db_file: @db_file)
    assert File.exist?(@db_file), "Database file should exist"

    block.call

    @db.close
    File.delete(@db_file)
  end

  def test_db_create_table_and_insert
    create_database do
      @db.execute("CREATE TABLE test (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)")
      @db.execute("INSERT INTO test (name) VALUES (?)", "test")
      ret = @db.execute("SELECT * FROM test")
      assert_equal "test", ret.first["name"]
    end
  end
end
