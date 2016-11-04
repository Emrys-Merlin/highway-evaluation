#!/usr/bin/ruby
# frozen_string_literal: true

require 'daru'
include Daru

# This class is a wrapper around daru dataframes.
# It takes timestamps from highway background concentration
# measurements and computs associated quantities (i.e. average
# background nox and co2, duration of the measurement,...)
class Background < Daru::DataFrame
  def initialize(source, opts = {})
    super
    setup
  end

  def self.from_csv(path, opts = {}, &block)
    new(super.to_h)
  end

  def duration
    self[:duration] = self[:stopdt, :startdt].collect_rows do |row|
      result = ((row[:stopdt] - row[:startdt]) * 24 * 60 * 60).to_i
      raise 'Negative duration detected.' if result.negative?
      result
    end
  end

  # offset between the time the instrument was close enough to the
  # measured vehicle and the time when the exhaust gases reached the
  # actual measurement chamber. Should be around 20 seconds.
  def offset(offset = 20)
    self[:offset] = Daru::Vector[Array.new(nrows, offset)]
  end

  def retrieve_background(raw_path, cn)
    raise 'No path to timeseries file given' if raw_path.nil?

    ts = DataFrame.from_csv(raw_path)
    ts.vectors = Index.new(ts.vectors.to_a.map(&:to_sym))
    ts.index = DateTimeIndex.new(ts[:timestamp])
    self[cn] = Daru::Vector.new_with_size(nrows)
    map_rows! do |row|
      start = row[:startdt]
      stop = row[:stopdt]
      range = ts[:timestamp].collect do |t|
        (start <= t) && t < stop ? true : false
      end
      row[cn] = average(ts[cn].where(range)) if range.include?(true)
      row
    end
  end

  private

  def setup
    self.vectors = Index.new(vectors.to_a.map(&:to_sym))

    residue = [:start, :stop, :date, :tz] - @vectors.to_a

    unless residue.empty?
      raise 'The columns start, stop, date and tz are necessary.'
    end

    convert_to_dt
  end

  def convert_to_dt
    self[:startdt] = Daru::Vector.new(Array.new(nrows))
    self[:stopdt] = Daru::Vector.new(Array.new(nrows))
    map_rows! do |row|
      start = row[:date] + ' ' + row[:start] + ' ' + row[:tz]
      stop = row[:date] + ' ' + row[:stop] + ' ' + row[:tz]
      format = '%d.%m.%Y %H:%M:%S %Z'
      row[:startdt] = DateTime.strptime(start, format)
      row[:stopdt] = DateTime.strptime(stop, format)
      row
    end
  end

  def average(frame)
    lastr = nil
    lasti = nil
    res = 0.0 # Daru::Vector[frame.vectors.to_a]
    weight = 0.0

    frame.each_with_index do |r, i|
      unless lastr.nil?
        di = (i - lasti)
        res += (r + lastr) * 0.5 * di
        weight += di
      end
      lastr = r
      lasti = i
    end

    res /= weight
    res
  end
end
