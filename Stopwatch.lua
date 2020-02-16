local socket = require("socket")

local Stopwatch = {}

local function math_sign(v)
   return (v >= 0 and 1) or -1
end

local function math_round(v, digits)
   digits = digits or 0
   local bracket = 1 / (10 ^ digits)
   return math.floor(v/bracket + math_sign(v) * 0.5) * bracket
end

function Stopwatch:new(...)
   local tbl = setmetatable({}, { __index = Stopwatch })
   tbl:init(...)
   return tbl
end

function Stopwatch:init(precision)
   self.time = socket.gettime()
   self.framerate = 60
   self.precision = precision or 5
end

function Stopwatch:measure()
   local new = socket.gettime()
   local result = new - self.time
   self.time = new
   return math_round(result * 1000, self.precision)
end

local function msecs_to_frames(msecs, framerate)
   local msecs_per_frame = (1 / framerate) * 1000
   local frames = msecs / msecs_per_frame
   return frames
end

function Stopwatch:measure_and_format(text)
   if text then
      text = string.format("[%s]", text)
   else
      text = ""
   end

   local msecs = self:measure()
   return string.format("%s\t%02." .. string.format("%02d", self.precision) .. "fms\t(%02.02f frames)",
                        text,
                        msecs,
                        msecs_to_frames(msecs, self.framerate))
end

function Stopwatch:p(text)
   print(self:measure_and_format(text))
end

function Stopwatch:bench(f, ...)
   self:measure()
   f(...)
   return self:measure_and_format()
end

return Stopwatch
