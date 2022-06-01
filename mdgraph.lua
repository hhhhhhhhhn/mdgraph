#!/usr/bin/lua
local parse = dofile("./parse.lua")

local layout
if #arg < 2 or #arg[1] < 3 then
	layout = "dot"
else
	layout = arg[1]
end

local function split(input, delimeter)
	local parts = {}
	for substring in input:gmatch("[^" .. delimeter .. "]+") do
		table.insert(parts, substring)
	end
	return parts
end

local function get_indent(line, previous)
	local indent = 0
	for i = 1, #line do
		local char = string.sub(line, i, i)
		if char == " " then
			indent = indent + 1
		elseif char == "-" or char == "#" then
			return math.floor(indent/2)
		else
			return previous
		end
	end
	-- Empty line
	return previous
end

local function indentation_to_brackets(input)
	local indent = 0
	local output = ""
	for _, line in ipairs(split(input, "\n")) do
		local newindent = get_indent(line, indent)
		while indent < newindent do
			output = output .. "{\n"
			indent = indent + 1
		end
		while indent > newindent do
			output = output .. "}\n"
			indent = indent - 1
		end
		output = output .. line .. "\n"
	end
	while indent > 0 do
		output = output .. "\n}"
		indent = indent - 1
	end
	return output
end

local function remove_beggining(input)
	local start = input:find("#+[^\n]+\n%-")
	if not start then
		return "Graph not found"
	end
	return input:sub(start)
end

function Program(input)
	return parse.some("Program",
		parse.list("", Graph, Whitespace)
	)(input)
end

function Graph(input)
	return parse.list("Graph", Header, Nodes)(input)
end

function Header(input)
	return parse.list("Header",
		parse.pattern("", "#+ "),
		parse.pattern("Title", "[^%-]*")
	)(input)
end

function Nodes(input)
	return parse.some("Nodes", Node)(input)
end

function Node(input)
	return parse.list("Node",
		parse.pattern("", "%- "),
		parse.either(TitleText, parse.pattern("Text", "[^%-{}#]*")),
		parse.optional(Children)
	)(input)
end

function TitleText(input)
	return parse.list("TitleText",
        parse.pattern("Text", "[^%-{}#:]*"),
		parse.pattern("", ":"),
        parse.pattern("Text", "[^%-{}#]*")
	)(input)
end

function Children(input)
	return parse.list("Children",
		parse.pattern("", "{[^%-{}#]*"),
		Nodes,
		parse.pattern("", "}[^%-{}#]*")
	)(input)
end

Whitespace = parse.pattern("", "%s*")

local function wordwrap(input, width)
	local words = split(input, "%s+")
	local out = ""
	local currentx = 0
	for _, word in ipairs(words) do
		if currentx + #word + 1 > width then
			currentx = 0
			out = out .. "\n"
		end
		out = out .. word .. " "
		currentx = currentx + #word + 1
	end
	return out
end

local function escape(input)
	return input:gsub("\n", "<BR/>"):gsub('"', "'")
end

local function formatbold(input)
	input = input:gsub("%*+", "*")
	local count = 1
	while count > 0 do
		input = input:gsub("%*", "<B>", 1)
		input, count = input:gsub("%*", "</B>", 1)
	end
	return input
end

local function format(input)
	local width = math.max(math.sqrt(#input) * 3, 20)
	local formatted = formatbold(escape(wordwrap(input, width)))
	return formatted:gsub("^%s*", ""):gsub("%s*$", "")
end

local function randid()
	return math.random(1,99999999)
end

function Eval(node, parent)
	if not node then
		return ""
	end
	if node.type == "Program" then
		local output = ""
		for i, graph in ipairs(node.children) do
			print(Eval(graph.children[1], i))
			-- output = output .. Eval(graph.children[1], i)
		end
		return output
	elseif node.type == "Graph" then
		local id = randid()
		return string.format(
[[digraph D%i {
    layout=%s
    graph [ranksep=1]
    overlap=false
    splines=true
    node [shape=rectangle, fontsize=20]
    %i [label=<<B>%s</B>>, fontsize=30]
%s
} ]],
		parent,
		layout,
		id,
		format(node.children[1].children[2].value),
		Eval(node.children[2], id))
	elseif node.type == "Nodes" then
		local output = ""
		for _, child in ipairs(node.children) do
			output = output .. Eval(child, parent) .. "\n"
		end
		return output
	elseif node.type == "Children" then
		return Eval(node.children[2], parent)
	elseif node.type == "Node" then
		local id = randid()
		return string.format(
[[
    %d -> %d
    %d [label=<%s>]
%s]],
		parent, id, id, Eval(node.children[2]), Eval(node.children[3], id))
	elseif node.type == "Text" then
		return format(node.value)
	elseif node.type == "TitleText" then
		return string.format("<B>%s</B><BR/>%s", Eval(node.children[1]), Eval(node.children[3]))
	end
	return ""
end

local function main()
	local stdin = io.read("*a")
	local input = indentation_to_brackets(remove_beggining(stdin))
	local parsed, rest = Program(input)
	if rest:find("%S") then
		io.stderr:write("\27[31m\27[1mUNPARSED:\n" .. rest .. "\27[0m\n")
	end
	print(Eval(parsed))
end

 main()
