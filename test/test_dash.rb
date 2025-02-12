require_relative 'lib/ash'

class DashboardTest < Minitest::Test
  include Ash

  def _sys_class
    Dashboard
  end

  def _sys_abbrev
    'dash'
  end
end