#!/usr/bin/env ruby

#Jika file yang akan di includekan berada satu folder yang sama# gunakan tanda. / sebelum nama file

require './pray_time.rb'

p = PrayTime.new

lat = -7.8000
lng = 110.3667

dt = DateTime.now
dt_y = dt.year
dt_m = dt.month
dt_d = dt.day

p.set_calc_method(3)
p.set_asr_method(0)

sch_pray = p.get_prayer_times(dt_y, dt_m, dt_d, lat, lng, 7)
i = 0
time_names = p.get_time_names
sch_pray.each do |
ptime |
	puts "#{time_names[i]} #{ptime}"
i += 1
end