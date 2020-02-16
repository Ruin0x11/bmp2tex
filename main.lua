local cands = {}

local img
local index = 1
local key_color = {43, 133, 133}

function love.load()
   for _, item in ipairs(love.filesystem.getDirectoryItems("graphic")) do
      print(item)
      if string.match(item, "%.bmp$") then
         cands[#cands+1] = "graphic/" .. item
      end
   end
   assert(cands[index])

   img = BMPConvert.convert(cands[index], key_color)
end

local pressed

function love.update(arg)
   if love.keyboard.isDown("q") then
      love.event.quit()
   end
   if love.keyboard.isDown("up") then
      if not pressed or love.keyboard.isDown("lshift") then
         index = index + 1
         if index > #cands then
            index = 1
         end
         img = BMPConvert.convert(cands[index], key_color)
         pressed = true
      end
   elseif love.keyboard.isDown("down") then
      if not pressed or love.keyboard.isDown("lshift") then
         index = index - 1
         if index < 1 then
            index = #cands
         end
         img = BMPConvert.convert(cands[index], key_color)
         pressed = true
      end
   else
      pressed = false
   end
end

function love.draw(arg)
   love.graphics.clear(0.2, 0.2, 0.2)
   love.graphics.draw(img, 16, 16)
end
