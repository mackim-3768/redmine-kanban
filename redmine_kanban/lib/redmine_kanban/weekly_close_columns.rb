require 'date'

module RedmineKanban
  module WeeklyCloseColumns
    WEEK_COUNT = 4

    module_function

    def recent_weeks(today, count = WEEK_COUNT)
      current_week_start = today - (today.cwday - 1)

      (1..count).map do |weeks_ago|
        start_on = current_week_start - (weeks_ago * 7)
        {
          key: "closed_week_#{start_on.cwyear}_#{format('%02d', start_on.cweek)}",
          week: start_on.cweek,
          start_on: start_on,
          end_on: start_on + 7
        }
      end
    end

    def key_for(date, weeks)
      return if date.nil?

      closed_on = date.to_date
      week = weeks.find { |item| closed_on >= item[:start_on] && closed_on < item[:end_on] }
      week && week[:key]
    end
  end
end
