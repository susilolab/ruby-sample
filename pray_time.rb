#
# pray_time.rb
#
# Library class for calculation of pray time sholat. Adaptation from pray_time.cs
#
# @author    Agus Susilo <smartgdi@gmail.com>
# @date      6 Januari 2013 23:21 WIB
# @copyright 2013 Susilolabs
#
require 'time'

class PrayTime
	def initialize
		@jafari      = 0
		@karachi     = 1
		@isna        = 2
		@mwl         = 3
		@makkah      = 4
		@eqypt       = 5
		@custom      = 6
		@tehran      = 7

		@shaffi      = 0
		@hanafi      = 1

		@none        = 0
		@midnight    = 1
		@one_seventh = 2
		@angle_based = 3

		@time24      = 0
		@time12      = 1
		@time12_ns   = 2
		@floats      = 3

		@time_names = [
			"Fajr",
			"Sunrise",
			"Dhuhr",
			"Asr",
			"Sunset",
			"Maghrib",
			"Isha"
		]

		@invalid_time = "-----"

		@calc_method      = 0
		@asr_juristic     = 0
		@dhuhr_minutes    = 0
		@adjust_high_lats = 1
		@time_format      = 0

		@lat = 0.0
		@lng = 0.0
		@time_zone = 0
		@jdate = 0

		@num_iterations = 1
		@method_params = [
			[16, 0, 4, 0, 14],
			[18, 1, 0, 0, 18],
			[15, 1, 0, 0, 15],
			[18, 1, 0, 0, 17],
			[18.5, 1, 0, 1, 90],
			[19.5, 1, 0, 0, 17.5],
			[17.7, 0, 4.5, 0, 14],
			[18, 1, 0, 0, 17]
		]
	end

	def get_time_names
		@time_names
	end

	def set_calc_method(method_id)
		@calc_method = method_id
	end

	def set_custom_params(param)
		0.upto(4) do |i|
			if param[i] == -1
				@method_params[@custom][i] = @method_params[@calc_method][i]
			else
				@method_params[@custom][i] = param[i]
			end
		end
		@calc_method = @custom
	end

	def day_portion(times)
		0.upto(times.length-1) do |i|
      times[i] = times[i] / 24
	  end
		times
	end

	def night_portion(angle)
		val = 0
		val = 1.0/60.0* angle if @adjust_high_lats == @angle_based
		val = 1.0/2.0 if @adjust_high_lats == @midnight
		val =1.0/7.0 if @adjust_high_lats == @one_seventh

		val
	end

	def get_prayer_times(year, month, day, lat, lng, time_zone)
		get_date_prayer_times(year, month + 1, day, lat, lng, time_zone)
	end

	def get_date_prayer_times(year, month, day, lat, lng, time_zone)
		@lat = lat
		@lng = lng
		@time_zone = time_zone
		@jdate = julian_date(year, month, day) - lng/(15 * 24)
		compute_day_times
	end

	def julian_date(year, month, day)
		if month <= 2
			year  -= 1
			month += 12
		end

		a  = (year/100).floor
		b  = 2 - a + (a/4).floor
		jd = (365.25 * (year + 4716)).floor + (30.6001 * (month + 1)).floor + day + b - 1524.5
		jd
	end

	def compute_day_times
		times = [5, 6, 12, 13, 18, 18, 18]
		1.upto(@num_iterations) { |i|
			times = compute_times(times)
		}

		times = adjust_times(times)
		adjust_times_format(times)
	end

	def compute_time(g, t)
		d   = sun_declination(@jdate + t)
		z   = compute_midday(t)
		beg = -dsin(g) - dsin(d) * dsin(@lat)
		mid = dcos(d) * dcos(@lat)
		v   = darccos(beg / mid) / 15.0
		(z + (g > 90? -v : v) )
	end

	def compute_times(times)
		t = day_portion(times)

		fajr    = compute_time((180.0- @method_params[@calc_method][0].to_f), t[0])
		sunrise = compute_time(180.0- 0.833, t[1])
		dhuhr   = compute_midday(t[2])
		asr     = compute_asr(1+ @asr_juristic, t[3])
		sunset  = compute_time(0.833, t[4])
		maghrib = compute_time(@method_params[@calc_method][2], t[5])
		isha    = compute_time(@method_params[@calc_method][4], t[6])

		[fajr, sunrise, dhuhr, asr, sunset, maghrib, isha]
	end

	def compute_asr(step, t)
		d = sun_declination(@jdate + t)
		g = -darccot(step + dtan((@lat - d).abs))
		compute_time(g, t)
	end

	def compute_midday(t)
		tm = equation_of_time(@jdate + t)
		z  = fix_hour(12 - tm)
		z
	end

	def sun_declination(jd)
		sun_position(jd)[0]
	end

	def sun_position(jd)
		da = jd - 2451545.0
		g  = fix_angle(357.529 + 0.98560028* da)
		q  = fix_angle(280.459 + 0.98564736* da)
		l  = fix_angle(q + 1.915* dsin(g) + 0.020* dsin(2*g))

		r = 1.00014 - 0.01671* dcos(g) - 0.00014* dcos(2*g)
		e = 23.439 - 0.00000036* da

		d   = darcsin(dsin(e)* dsin(l))
		ra  = darctan2(dcos(e) * dsin(l), dcos(l))/ 15
		ra  = fix_hour(ra)
		eqt = q/15 - ra

		[d, eqt]
	end

	def equation_of_time(jd)
		sun_position(jd)[1]
	end

	def float_to_time12ns(time)
		float_to_time12(time, true)
	end

	def float_to_time12(time, no_suffix)
		return @invalid_time if time < 0

		time    = fix_hour(time+ 0.5/ 60) # add 0.5 minutes to round
		hours   = time.floor;
		minutes = ((time- hours)* 60).floor
		suffix  = hours >= 12 ? " pm" : " am"
		hours   = (hours+ 12 -1)% 12+ 1
		hours.to_s + ":" + two_digits_format(minutes) + (no_suffix ? "" : suffix)
	end

	def float_to_time24(time)
		return @invalid_time if time < 0

		time    = fix_hour(time+ 0.5/ 60) # add 0.5 minutes to round
		hours   = time.floor
		minutes = ((time- hours)* 60).floor
		two_digits_format(hours) + ":" + two_digits_format(minutes)
	end

	def two_digits_format(num)
		(num < 10)? "0" + num.to_s: num.to_s
	end

	def get_time_diff(c1, c2)
		diff = fix_hour(c2 - c1)
		diff
	end

	def adjust_times(times)
		0.upto(6) { |i|
			times[i] += @time_zone - @lng/15
		}

		times[2] += @dhuhr_minutes/ 60 # Dhuhr
		if @method_params[@calc_method][1] == 1 # Maghrib
			times[5] = times[4]+ @method_params[@calc_method][2]/ 60.0
		end

		if @method_params[@calc_method][3] == 1 # Isha
			times[6] = times[5]+ @method_params[@calc_method][4]/ 60.0
		end

	  if @adjust_high_lats == 1
	    time = adjust_high_lat_times(times)
	  end
	  times
	end

	def adjust_times_format(times)
		formatted = []
		if @time_format == @floats
			0.upto(times.length - 1) { |i|
				formatted[i] = times[i].to_s + ""
			}
			return formatted
		end

		0.upto(6) { |i|
			if @time_format == @time12
				formatted[i] = float_to_time12(times[i], true)
			elsif @time_format == @time12_ns
				formatted[i] = float_to_time12ns(times[i])
			else
				formatted[i] = float_to_time24(times[i])
			end
		}
		return formatted
	end

	def adjust_high_lat_times(times)
		night_time =  get_time_diff(times[4], times[1]) # sunset to sunrise

		# Adjust Fajr
		fajr_diff =  night_portion(@method_params[@calc_method][0]) * night_time
		if get_time_diff(times[0], times[1]) > fajr_diff
			times[0] = times[1]- fajr_diff
		end

		# Adjust Isha
		isha_angle = (@method_params[@calc_method][3] == 0) ? @method_params[@calc_method][4] : 18
		isha_diff =  night_portion(isha_angle) * night_time
		if get_time_diff(times[4], times[6]) > isha_diff
			times[6] = times[4]+ isha_diff
		end

		# Adjust Maghrib
		maghrib_angle = (@method_params[@calc_method][1] == 0) ? @method_params[@calc_method][2] : 4
		maghrib_diff =  night_portion(maghrib_angle)* night_time
		if get_time_diff(times[4], times[5]) > maghrib_diff
			times[5] = times[4]+ maghrib_diff
		end

		return times
	end

	def set_time_format(time_format)
		@time_format = time_format
	end

	def set_asr_method(method_id)
		return if method_id < 0 || method_id > 1
		@asr_juristic = method_id
	end

	def set_fajr_angle(angle)
		set_custom_params([angle, -1, -1, -1, -1])
	end

	def set_maghrib_angle(angle)
		set_custom_params([-1, 0, angle, -1, -1])
	end

	def set_maghrib_minutes(minutes)
		set_custom_params([-1, -1, minutes, -1, -1])
	end

	def set_isha_angle(angle)
		set_custom_params([-1, -1, -1, 0, angle])
	end

	def set_isha_minutes(minutes)
		set_custom_params([-1, -1, -1, -1, minutes])
	end

	def set_dhuhr_minutes(minutes)
		@dhuhr_minutes = minutes
	end

	def dsin(d)
		Math.sin(degree_to_radian(d))
	end

	def dcos(d)
		Math.cos(degree_to_radian(d))
	end

	def dtan(d)
		Math.tan(degree_to_radian(d))
	end

	def darcsin(x)
		radian_to_degree(Math.asin(x))
	end

	def darccos(x)
		radian_to_degree(Math.acos(x))
	end

	def darctan(x)
		radian_to_degree(Math.atan(x))
	end

	def darctan2(x, y)
		radian_to_degree(Math.atan2(x, y))
	end

	def darccot(x)
		radian_to_degree(Math.atan(1/x))
	end

	def fix_angle(angel)
		angel = angel - 360.0 * (angel / 360.0).floor
		angel = angel < 0? angel + 360.0 : angel
		angel
	end

	def fix_hour(hour)
		hour = hour - 24.0 * (hour/24.0).floor
		hour = hour < 0? hour + 24.0 : hour
		hour
	end

	def degree_to_radian(degree)
		(degree * Math::PI) / 180.0
	end

	def radian_to_degree(radian)
		(radian * 180) / Math::PI
	end
end
