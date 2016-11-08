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
  # actual measurement chamber. Should be around 20 seconds. For CO2
  # time series the CO2 offset to NOx has to also be included.
  def offset(offset = 20)
    self[:offset] = Daru::Vector[Array.new(nrows, offset)]
    self[:startdt] += self[:offset].recode do |o|
      o.to_f/(60.0*60.0*24.0)
    end
    self[:stopdt] += self[:offset].recode do |o|
      o.to_f/(60.0*60.0*24.0)
    end
    self
  end

  # TODO: add error propagation. needs to be done in average
  def retrieve_background(raw_path, cn)
    raise 'No path to timeseries file given' if raw_path.nil?

    ts = DataFrame.from_csv(raw_path)
    ts.vectors = Index.new(ts.vectors.to_a.map(&:to_sym))
    ts[:timestamp].map! do |t|
      DateTime.parse(t) if t.is_a?(String)
    end
    self[cn] = Daru::Vector.new_with_size(nrows)
    map_rows! do |row|
      start = row[:startdt]
      stop = row[:stopdt]
      range = ts[:timestamp].collect do |t|
        (start <= t) && t <= stop ? true : false
      end
      row[cn] = average(ts[:timestamp, cn].where(range), cn) if range.include?(true)
      row
    end
  end

  def write_csv(filename, opts = {})
    self[*(vectors.to_a - [:startdt, :stopdt])].write_csv(filename, opts)
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
    [:startdt, :stopdt].each{|s| self[s] = Daru::Vector.new_with_size(nrows) }
    map_rows! do |row|
      format = '%d.%m.%Y%H:%M:%S%Z'
      [:start, :stop].each do |s|
        row[(s.to_s + 'dt').to_sym] = DateTime.strptime(row[:date] + row[s] +
                                                        row[:tz], format)
      end
      row
    end
  end

  def average(frame, cn)
    lastr = nil
    res = 0.0
    weight = 0.0

    frame.each_row do |r|
      unless lastr.nil?
        di = (r[:timestamp] - lastr[:timestamp])*24*60*60
        res += (r[cn] + lastr[cn]).to_f * 0.5 * di
        weight += di
      end
      lastr = r
    end
    res /= weight
    res
  end
end
