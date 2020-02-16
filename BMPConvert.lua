local BinaryReader = require("BinaryReader")
local Stopwatch = require("Stopwatch")

local ffi, fs, vips
if jit then
   ffi = require("ffi")
   fs = require("util.fs")
   vips = require("vips")
end

local BMPConvert = {}

local BI_RGB = 0
local BI_RLE8 = 1
local BI_RLE4 = 2
local BI_BITFIELDS = 3

local function get_bmp_version(header_size, compression)
   if header_size == 12 then
      return "2"
   elseif header_size == 40 then
      if compression == BI_BITFIELDS then
         return "3nt"
      else
         return "3"
      end
   elseif header_size == 100 then
      return "4"
   elseif header_size == 124 then
      return "five"
   end
   error("invalid BMP type: " .. tostring(header_size))
end


local function convert_lua51(filepath, key_color)
   local sw = Stopwatch:new()

   local bmp = BinaryReader:new()
   BinaryReader:open(filepath)
   print(filepath)

   local kind = bmp:str(2)
   assert(kind == "BM")

   local size = bmp:u32()
   bmp:skip(4)
   local offset = bmp:u32()

   print("Size:", size)
   print("Offset:", offset)

   local bsize = bmp:u32()
   local bwidth = bmp:i32()
   local bheight = bmp:i32()
   local bplanes = bmp:u16()
   local bbitcount = bmp:u16()
   local bcompression = bmp:u32()
   local bsizeimage = bmp:u32()
   local bxpelspermeter = bmp:i32()
   local bypelspermeter = bmp:i32()
   local bclrused = bmp:u32()
   local bclrimportant = bmp:u32()

   print("bsize", bsize)
   print("bwidth", bwidth)
   print("bheight", bheight)
   print("bplanes", bplanes)
   print("bbitcount", bbitcount)
   print("bcompression", bcompression)
   print("bsizeimage", bsizeimage)
   print("bxpelspermeter", bxpelspermeter)
   print("bypelspermeter", bypelspermeter)
   print("bclrused", bclrused)
   print("bclrimportant", bclrimportant)

   local bmp_version = get_bmp_version(bsize, bcompression)
   print("version: ", bmp_version)

   if bbitcount ~= 8 and bbitcount ~= 24 then
      error("bit count unsupported: " .. tostring(bbitcount))
   end

   local key_r, key_g, key_b
   if key_color then
      key_r = key_color[1]
      key_g = key_color[2]
      key_b = key_color[3]
   end

   bmp:seek(14 + bsize)

   local color_table

   if bbitcount <= 8 then
      color_table = {}
      local color_table_size

      if bclrused > 0 then
         color_table_size = bclrused
      else
         color_table_size = bit.lshift(1, bbitcount)
      end

      if bmp_version == "2" then
         for i=0,color_table_size-1 do
            local b = bmp:u8()
            local g = bmp:u8()
            local r = bmp:u8()
            if key_r == r and key_g == g and key_b == key_b then
               color_table[i] = string.char(0, 0, 0, 0)
            else
               color_table[i] = string.char(r, g, b, 255)
            end
         end
      else
         for i=0,color_table_size-1 do
            local b = bmp:u8()
            local g = bmp:u8()
            local r = bmp:u8()
            local _ = bmp:u8()
            if key_r == r and key_g == g and key_b == key_b then
               color_table[i] = string.char(0, 0, 0, 0)
            else
               color_table[i] = string.char(r, g, b, 255)
            end
         end
      end
   end

   sw:p("BMP Header Read")

   local pixels = {}

   local size = bwidth * bheight

   bmp:seek(offset)

   local bytes_per_row = math.ceil(bwidth / (8 / bbitcount))
   local padding = 0
   if bytes_per_row % 4 > 0 then
      padding = 4 - (bytes_per_row % 4)
   end
   print(bytes_per_row, padding)

   if color_table then
      if bcompression == BI_RGB then
         if bbitcount == 8 then
            for y=1,bheight do
               for x=bwidth,1,-1 do
                  local index = bmp:u8()
                  pixels[size-y*bwidth+x] = color_table[index]
               end
               bmp:skip(padding)
            end
         else
            error("bitcount unsupported: " .. tostring(bbitcount))
         end
      else
         error("compression unsupported: " .. tostring(bcompression))
      end
   else
      if bcompression == BI_RGB then
         if bbitcount == 24 then
            for y=1,bheight do
               for x=1,bwidth do
                  local b = bmp:u8()
                  local g = bmp:u8()
                  local r = bmp:u8()
                  local i = size-y*bwidth+x
                  if key_r == r and key_g == g and key_b == key_b then
                     pixels[i] = string.char(0, 0, 0, 0)
                  else
                     pixels[i] = string.char(r, g, b, 255)
                  end
               end
               bmp:skip(padding)
            end
         else
            error("bitcount unsupported: " .. tostring(bbitcount))
         end
      else
         error("compression unsupported: " .. tostring(bcompression))
      end
   end

   sw:p("BMP Load")

   local data = love.image.newImageData(bwidth, bheight, "rgba8", table.concat(pixels))
   local image = love.graphics.newImage(data)

   sw:p("Image Alloc")

   return image
end


local function remove_key_color(image, key_color)
   if image:bands() == 4 then
      key_color[4] = 0
   end
   local alpha = image:equal(key_color):ifthenelse(0, 255):bandor()
   return image:bandjoin(alpha)
end

local function convert_luajit(filepath, key_color)
   local vips_image = vips.Image.new_from_file(filepath)

   if key_color then
      vips_image = remove_key_color(vips_image, key_color)
   end

   vips_image = vips_image:cast("ushort")

   local buffer = vips_image:write_to_memory()
   local image_data = love.graphics.newImageData(vips_image:width(),
                                                 vips_image:height(),
                                                 "rgba16",
                                                 ffi.string(buffer))
   return love.graphics.newImage(image_data)
end

if jit then
   BMPConvert.convert = convert_luajit
else
   BMPConvert.convert = convert_lua51
end

return BMPConvert
