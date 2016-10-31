#!/usr/bin/ruby

require 'daru'
include Daru

# This class is a wrapper around daru dataframes.
# It takes timestamps from highway background concentration
# measurements and computs associated quantities (i.e. average
# background nox and co2, duration of the measurement,...)
class Background
  attr_accessor :df, :path

  def initialize(path)
    @path = path
    @df = DataFrame.from_csv(path)
    @df.vectors = Index.new(@df.vectors.to_a.map{|i| i.to_sym})

    raise 'A column called \'start\' ist needed.' unless @df.vectors.to_a.include?(:start)
    raise 'A column called \'stop\' ist needed.' unless @df.vectors.to_a.include?(:stop)
    raise 'A column called \'date\' ist needed.' unless @df.vectors.to_a.include?(:date)
    raise 'A column called \'tz\' ist needed.' unless @df.vectors.to_a.include?(:tz)

    @df[:startdt] = Daru::Vector.new(Array.new(@df.nrows))
    @df[:stopdt] = Daru::Vector.new(Array.new(@df.nrows))

    @df.map_rows! do |row|
      start = row[:date] + ' ' + row[:start] + '' + row[:tz]
      stop = row[:date] + ' ' + row[:stop] + '' + row[:tz]
      format = '%d.%m.%Y %H:%M:%S %Z'
      row[:startdt] = DateTime.strptime(start, format)
      row[:stopdt] = DateTime.strptime(stop, format)
      row
    end
  end

  def duration
    @df[:duration] = @df[:stopdt, :startdt].collect_rows do |row|
      result = ((row[:stopdt] - row[:startdt])*24*60*60).to_i
      raise 'Negative duration detected.' if result < 0
      result
    end
  end

  def save(path = nil)
    @path = path unless path.nil?
    @df.write_csv(path)
  end
end
