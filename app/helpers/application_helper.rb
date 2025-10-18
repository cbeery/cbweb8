module ApplicationHelper
	def zone_time(time)
		local_time(time, '%l:%M%P %Z')
	end
end
