-- Setup
local pandoc = require 'pandoc'
local utils = require 'pandoc.utils'
local system = require 'pandoc.system'
local path = require 'pandoc.path'

-- Global Variables
local counter = 0
local folder = system.get_working_directory()

-- Enums
local D2Theme = {
  NeutralDefault = 0,
  NeutralGrey = 1,
  FlagshipTerrastruct = 3,
  CoolClassics = 4,
  MixedBerryBlue = 5,
  GrapeSoda = 6,
  Aubergine = 7,
  ColorblindClear = 8,
  VanillaNitroCola = 100,
  OrangeCreamsicle = 101,
  ShirelyTemple = 102,
  EarthTones = 103,
  EvergladeGreen = 104,
  ButteredToast = 105,
  DarkMauve = 200,
  Terminal = 300,
  TerminalGrayscale = 301,
  Origami = 302,
}

local D2Layout = {
  dagre = "dagre",
  elk = "elk",
  tala = "tala",
}

local D2Format = {
  svg = "svg",
  png = "png",
  pdf = "pdf",
}

-- Default Filter Options
local options = {
  theme = D2Theme.NeutralDefault,
  layout = D2Layout.dagre,
  format = D2Format.svg,
  sketch = false,
  pad = 100,
}

-- Filter Function
function CodeBlockFilter(block)
  if block.t ~= "CodeBlock" then return nil end
  local attrs = block.attr
  local content = block.text
  local id = attrs.identifier
  local classes = attrs.classes

  -- Continue only if 'd2' class is present
  if not utils.inlines_to_string(classes):find('d2') then return nil end

  local imageAttrs = {}

  for k, v in pairs(attrs.attributes) do
    if k == 'theme' then
      if tonumber(v) ~= nil and D2Theme[tonumber(v)] ~= nil then
        options.theme = tonumber(v)
      else
        local themeNamePascal = v:gsub("(%a)([%w_']*)", function (first, rest) return first:upper()..rest:lower() end)
        if D2Theme[themeNamePascal] ~= nil then
          options.theme = D2Theme[themeNamePascal]
        end
      end
    elseif k == 'sketch' then
      options.sketch = v == 'true'
    elseif k == 'layout' then
      if D2Layout[v] ~= nil then options.layout = v end
    elseif k == 'format' then
      if D2Format[v] ~= nil then options.format = v end
    elseif k == 'pad' then
      options.pad = tonumber(v)
    elseif k == 'folder' or k == 'filename' or k == 'caption' then
      options[k] = v
    else
      table.insert(imageAttrs, {k, v})
    end
  end

  counter = counter + 1

  -- Create temp file
  local tmpFile = os.tmpname()
  local file = io.open(tmpFile, "w")
  file:write(content)
  file:close()

  local outDir = options.folder or ""

  -- Generate filename from caption if not provided
  if options.caption and not options.filename then
    options.filename = options.caption:gsub("(%a)([%w_']*)", function (first, rest) return first:upper()..rest:lower() end)
    options.filename = options.filename:gsub("%s+", ""):gsub("/", "-")
  end

  if not options.filename then
    options.filename = "diagram-" .. counter
  end

  local savePath = tmpFile .. "." .. options.format
  local newPath = path.join(outDir, options.filename .. "." .. options.format)

  -- Execute d2 command
  local fullCmd = "d2 --theme=" .. options.theme .. " --layout=" .. options.layout .. " --sketch=" .. tostring(options.sketch) .. " --pad=" .. options.pad .. " " .. tmpFile .. " " .. savePath
  os.execute(fullCmd)

    -- Handle different formats
  if not options.folder then
    if options.format == "svg" then
      local file = io.open(savePath, "r")
      local data = file:read("*all")
      file:close()
      newPath = "data:image/svg+xml;base64," .. pandoc.utils.encode_base64(data)
    elseif options.format == "pdf" then
      newPath = savePath
    else
      local file = io.open(savePath, "rb")
      local data = file:read("*all")
      file:close()
      newPath = "data:image/png;base64," .. pandoc.utils.encode_base64(data)
    end
  else
    local imageFolder = path.join(folder, outDir)
    if not path.exists(imageFolder) then
      os.execute("mkdir -p " .. imageFolder)
    end
    os.execute("mv " .. savePath .. " " .. newPath)
  end

  local fig = options.caption and "fig:" or ""

  return pandoc.Para({pandoc.Image({id, {}, imageAttrs}, {pandoc.Str(options.caption or "")}, {newPath, fig})})
end

-- Assign the Filter Function
return {
  {CodeBlock = CodeBlockFilter}
}
