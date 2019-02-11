class Workday < ApplicationRecord
  audited

  belongs_to :inventory_pool, inverse_of: :workday

  serialize :max_visits, Hash

  # deprecated
  DAYS = %w[monday tuesday wednesday thursday friday saturday sunday]

  # better
  WORKDAYS = %w[sunday monday tuesday wednesday thursday friday saturday]

  def open_on?(date)
    return false if date.nil?

    case date.wday
    when 1
      return monday
    when 2
      return tuesday
    when 3
      return wednesday
    when 4
      return thursday
    when 5
      return friday
    when 6
      return saturday
    when 0
      return sunday # Should not be reached
    else
      return false
    end
  end

  def closed_days
    days = []
    days << 0 unless sunday
    days << 1 unless monday
    days << 2 unless tuesday
    days << 3 unless wednesday
    days << 4 unless thursday
    days << 5 unless friday
    days << 6 unless saturday
    days
  end

  def workdays=(wdays)
    wdays.each_pair do |k, v|
      write_attribute(WORKDAYS[Integer(k.presence || 0)], Integer(v['open'].presence || 0))
      max_visits[Integer(k.presence || 0)] =
        v['max_visits'].blank? ? nil : Integer(v['max_visits'].presence || 0)
    end
  end

  def max_visits_on(weekday_number)
    max_visits[weekday_number]
  end

  def total_visits_by_date
    inventory_pool.visits.group_by(&:date)
  end

  def reached_max_visits
    dates = []
    total_visits_by_date.each_pair do |date, visits|
      next if date.past? or max_visits_on(date.wday).nil? or visits.size < max_visits_on(date.wday)
      dates << date
    end
    dates.sort
  end

  def label_for_audits
    "#{_('Workdays')} #{inventory_pool}"
  end
end
