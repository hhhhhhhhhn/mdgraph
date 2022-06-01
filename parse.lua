local parse = {}

local function pack(...)
	return { n = select("#", ...), ...}
end

function parse.pattern(name, pat)
	return (function (input)
		local start, endd = string.find(input, "^" .. pat)
		if start == nil or start > 1 then
			return nil
		end
		local match = string.sub(input, start, endd)
		local rest = string.sub(input, endd+1)
		return {type = name, value = match}, rest
	end)
end

function parse.list(name, ...)
	local parsers = pack(...)
	return (function (input)
		local rest = input
		local node = {type = name, children = {}}

		for _, parser in ipairs(parsers) do
			local child, parserRest = parser(rest)
			if child == nil then
				return nil
			end
			table.insert(node.children, child)
			rest = parserRest
		end

		return node, rest
	end)
end

function parse.either(...)
	local parsers = pack(...)
	return (function (input)
		for _, parser in ipairs(parsers) do
			local child, rest = parser(input)
			if child ~= nil then
				return child, rest
			end
		end
		return nil
	end)
end

function parse.some(name, parser)
	return (function (input)
		local rest = input
		local node = {type = name, children = {}}

		while true do
			local child, parserRest = parser(rest)
			if child == nil then
				return node, rest
			end
			table.insert(node.children, child)
			rest = parserRest
		end
	end)
end

function parse.optional(parser)
	return (function (input)
		local node, rest = parser(input)
		if node == nil then
			return {type = "empty"}, input
		end
		return node, rest
	end)
end

function parse.memoize(parser)
	local nodes = {}
	local rests = {}
	return function (input)
		if not nodes[input] then
			nodes[input], rests[input] = parser(input)
		end
		return nodes[input], rests[input]
	end
end

local function test()
	local expression, term, factor
	expression = function(input)
		return parse.either(parse.list("expression", term, parse.pattern("+", "%+"), expression), term)(input)
	end
	term = function(input)
		return parse.either(parse.list("term", factor, parse.pattern("*", "%*"), term), factor)(input)
	end
	factor = function(input)
		return parse.either(parse.list("factor", parse.pattern("(", "%("), expression, parse.pattern(")", "%)")), parse.pattern("number", "%d+"))(input)
	end

	local function eval(node)
		if node.type == "expression" then
			return eval(node.children[1]) + eval(node.children[3])
		elseif node.type == "term" then
			return eval(node.children[1]) * eval(node.children[3])
		elseif node.type == "factor" then
			return eval(node.children[2])
		elseif node.type == "number" then
			return tonumber(node.value)
		end
	end

	print("> 2*2*(5+7)")
	print("48")
	while true do
		io.write("> ")
		local line = io.read()
		local parsed, rest = expression(line)
		if parsed == nil or rest ~= "" then
			print("Invalid Input")
		else
			print(eval(parsed))
		end
	end
end

if false then
	test()
end
return parse
