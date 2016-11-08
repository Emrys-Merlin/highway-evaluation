#!/usr/bin/ruby
# coding: utf-8

require_relative 'background.rb'

# This class contains the table for one measurement day together with
# some helper methods to assign and correct for background and compute
# the ratios.
class Table < Background
  def initialize(path)
    super
  end

  def assign_background(bg_path, cns,
                        min_dur = 0, max_dist = Float::INFINITY)
    bg = load_bg(bg_path, min_dur)

    cns = [cns] unless cns.is_a?(Array)
    cns.each do |cn|
      self[(cn.to_s + '_background').to_sym] = Daru::Vector.new_with_size(nrows)
    end

    map_rows! do |row|
      start = row[:startdt]
      stop = row[:stopdt]

      cns.each do |cn|
        row[(cn.to_s + '_background').to_sym] = lookup(bg, cn, start,
                                                       stop, max_dist)
      end

      row
    end
  end

  # TODO: Fix such that NOx depends on CO2
  def find_min(raw_path, cn, interval)
    bg = DataFrame.from_csv(raw_path)
    bg.vectors = Index.new(bg.vectors.map(&:to_sym))

    residue = [:timestamp, cn] - bg.vectors.to_a
    raise "timestamp and #{cn} column necessary" unless residue.empty?

    interval = interval.to_f / (60.0 * 24.0)

    bg[:timestamp].map! do |t|
      DateTime.parse(t) if t.is_a?(String)
    end

    min = (cn.to_s + '_min').to_sym
    self[min] = Daru::Vector.new_with_size(nrows)

    map_rows! do |row|
      bstart = row[:startdt] - interval
      bstop = row[:startdt]
      astart = row[:stopdt]
      astop = row[:stopdt] + interval

      bi = bg[:timestamp].map do |t|
        (bstart <= t) && t < bstop ? true : false
      end

      ai = bg[:timestamp].map do |t|
        (astart <= t) && t < astop ? true : false
      end

      before = bg[cn].where(bi).min
      after = bg[cn].where(ai).min

      row[min] = [before, after].min
      row
    end
  end

  def compute_ratio(nox_path, co2_path, suffix = '_background',
                    co2_min = 0.0)
    nox = DataFrame.from_csv(nox_path)
    nox.vectors = Index.new(nox.vectors.map{|i| i.to_sym })
    co2 = DataFrame.from_csv(co2_path)
    co2.vectors = Index.new(co2.vectors.map{|i| i.to_sym })

    nox[:timestamp].map! do |t|
      DateTime.parse(t) if t.is_a?(String)
    end
    co2[:timestamp].map! do |t|
      DateTime.parse(t) if t.is_a?(String)
    end
    
    nox_bg = ('nox' + suffix).to_sym
    co2_bg = ('co2' + suffix).to_sym

    [nox_bg, co2_bg].each do |bg|
      unless vectors.to_a.include?(bg)
        self[bg] = Daru::Vector.new_with_size(nrows, 0.0)
      end
    end

    self[:ratio] = Array.new(nrows, 0.0)

    self.map_rows! do |row|
      start = row[:startdt]
      stop = row[:stopdt]

      noxl = nox.where(nox[:timestamp].map do |t|
                         start <= t and t < stop ? true : false
                       end)
      co2l = co2.where(nox[:timestamp].map do |t|
                         start <= t and t < stop ? true : false
                       end)

      lastr = nil
      lastt = nil
      weight = 0.0

      co2l.each_row do |r|
        noxi = nox[:timestamp].map do |t|
          t <= r[:timestamp]
        end
        next unless noxi.to_a.include?(true)
        n = noxl.where(noxi).last(1).row[0]
        if n[:timestamp] == r[:timestamp]
          value = n[:nox]
        else
          noxi = nox[:timestamp].map do |t|
            t > r[:timestamp]
          end
          break unless noxi.to_a.include?(true)
          m = noxl.where(noxi).first(1).row[0]
          # linear interpolation
          value = (m[:nox] - n[:nox]).to_f
          value /= (m[:timestamp] - n[:timestamp]).to_f
          value *= (r[:timestamp] - n[:timestamp]).to_f
          value += n[:nox].to_f
        end

        ratio = (value.to_f - row[nox_bg])
        ratio /= (r[:co2] - row[co2_bg])

        # trapezoidal rule
        unless lastr.nil?
          delta =  (r[:timestamp] - lastt)
          row[:ratio] += 0.5 * (ratio + lastr) * delta
          weight += delta
        end
        lastr = ratio
        lastt = r[:timestamp]
      end

      row[:ratio] /= weight

      row
    end
    self
  end

  # Converts the nox/co2 ratio to nox per kwh
  # TODO: implement!
  def convert_to_kwh
    self
  end

  # The NOx and CO2 time series may be shifted by a constant
  # time. This can be accounted for by the following column. It is
  # positive if a peak shows later in the CO2 time series than in the
  # NOx time series.
  def co2_offset(offset = 0.0)
    self[:co2_offset] = Daru::Vector[Array.new(nrows, offset)]
    self
  end

  private

  def load_bg(bg_path, min_dur)
    bg = DataFrame.from_csv(bg_path)
    bg.vectors = Index.new(bg.vectors.map(&:to_sym))
    bg = bg.where(
      bg[:duration].map do |d|
        d >= min_dur
      end
    )

    bg[:stopdt].map! do |s|
      DateTime.parse(s) if s.is_a?(String)
    end
    bg[:startdt].map! do |s|
      DateTime.parse(s) if s.is_a?(String)
    end
    bg
  end

  def lookup(bg, cn, start, stop, max_dist)
    before = bg.where(bg[:stopdt].map { |s| s < start }).last(1).row[0]
    after = bg.where(bg[:startdt].map { |s| s > stop }).first(1).row[0]

    db = (start - before[:stopdt]) * 24 * 60.to_f
    da = (after[:startdt] - stop) * 24 * 60.to_f

    unless db < max_dist || da < max_dist
      raise "No background value close enough."
    end

    (db < da ? before[cn] : after[cn])
  end
end
