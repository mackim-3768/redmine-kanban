require 'minitest/autorun'
require_relative '../../lib/redmine_kanban/weekly_close_columns'

class WeeklyCloseColumnsTest < Minitest::Test
  def test_builds_the_previous_four_iso_weeks
    weeks = RedmineKanban::WeeklyCloseColumns.recent_weeks(Date.new(2026, 8, 5))

    assert_equal [31, 30, 29, 28], weeks.map { |week| week[:week] }
    assert_equal Date.new(2026, 7, 27), weeks.first[:start_on]
    assert_equal Date.new(2026, 8, 3), weeks.first[:end_on]
  end

  def test_handles_iso_week_year_boundaries
    weeks = RedmineKanban::WeeklyCloseColumns.recent_weeks(Date.new(2026, 1, 5))

    assert_equal [
      'closed_week_2026_01',
      'closed_week_2025_52',
      'closed_week_2025_51',
      'closed_week_2025_50'
    ], weeks.map { |week| week[:key] }
  end

  def test_maps_only_dates_in_the_previous_four_weeks
    weeks = RedmineKanban::WeeklyCloseColumns.recent_weeks(Date.new(2026, 8, 5))

    assert_equal 'closed_week_2026_31', described_key(Date.new(2026, 7, 27), weeks)
    assert_equal 'closed_week_2026_31', described_key(Date.new(2026, 8, 2), weeks)
    assert_nil described_key(Date.new(2026, 8, 3), weeks)
    assert_nil described_key(Date.new(2026, 7, 5), weeks)
    assert_nil described_key(nil, weeks)
  end

  private

  def described_key(date, weeks)
    RedmineKanban::WeeklyCloseColumns.key_for(date, weeks)
  end
end
