require_relative 'lib/ash'

class RemoteDashboardTest < Minitest::Test
  include Ash

  def _sys_class
    RemoteDashboard
  end

  def _sys_abbrev
    'rash'
  end
end