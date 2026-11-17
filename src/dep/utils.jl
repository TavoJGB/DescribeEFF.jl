# Unemployment
function get_emp_stat(emp, selfemp, unemp)
	if !ismissing(emp) && (emp == 1)
		return "employed"
	elseif !ismissing(selfemp) && (selfemp == 1)
		return "employed"
	elseif !ismissing(unemp) && (unemp == 1)
		return "unemployed"
	else
		return "other"
	end
end