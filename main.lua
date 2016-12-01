local suit = require('suit')

--[[
    Various image/font assets
--]]
local FLOOR_IMAGE = love.graphics.newImage('assets/floor.png');
local PERSON_IMAGES = {
    love.graphics.newImage('assets/person1.png'),
    love.graphics.newImage('assets/person2.png'),
    love.graphics.newImage('assets/person3.png'),
    love.graphics.newImage('assets/person4.png')
}
local PERSON_SCALE = 1/8

local MERRIWEATHER = 'assets/Merriweather/Merriweather-Regular.ttf'
local ROBOTO = 'assets/Roboto/Roboto-Regular.ttf'
local OSWALD = 'assets/Oswald/Oswald-Regular.ttf'

local TITLE_FONT = love.graphics.newFont(MERRIWEATHER, 42)
local CONTROL_PANEL_FONT = love.graphics.newFont(MERRIWEATHER, 20)
local LABEL_FONT = love.graphics.newFont(MERRIWEATHER, 16)
local DATA_FONT = love.graphics.newFont(ROBOTO, 16)
local GRAPH_FONT = love.graphics.newFont(ROBOTO, 12)

--[[
    Coordinates
--]]
local X, Y = 1, 2

local TAU = math.pi * 2

local SPAWN_POINT_COORDS = {
    {808, 113}, -- UA2120
    {610, 113}, -- UA2130
    {408, 120}, -- UA2140
    {810, 527}, -- UA2220
    {608, 520}, -- UA2230
    {406, 515}  -- UA2240
}

local ROOM_DOOR_COORDS = {
    {{878, 163}, {734, 164}}, -- UA2120
    {{681, 164}, {536, 164}}, -- UA2130
    {{483, 164}            }, -- UA2140
    {{885, 473}, {724, 473}}, -- UA2220
    {{688, 473}, {527, 472}}, -- UA2230
    {{490, 473}            }  -- UA2240
}

local TOP_HALL, BOTTOM_HALL = 1, 2
local LEFT_CORNER, RIGHT_CORNER = 1, 2

local HALL_CORNER_COORDS = {
    {{416, 212}, {953, 212}}, -- top
    {{397, 435}, {955, 435}}  -- bottom
}

local LEFT_STAIR, RIGHT_STAIR = 1, 2
local STAIR_TOP, STAIR_BOTTOM = 1, 2
local STAIR_LEFT, STAIR_RIGHT = 1, 2

local STAIR_DOOR_COORDS = {
    {{378, 229}, {378, 229}}, -- left
    {{952, 279}, {952, 394}}  -- right
}

local STAIR_PATH_COORDS = {
    {{334, 239}, {222, 238}, {221, 280}, {328, 280}},
    {{952, 303}, {933, 303}, {860, 317}, {840, 337}, {862, 356}, {932, 369}}
}

local PHASE_ROOM_DOOR = 1
local PHASE_HALLWAY = 2
local PHASE_STAIR_DOOR = 3
local PHASE_EXIT = 4
local PHASE_DEAD = 5

--[[
    Other constants
--]]
local SAMPLE_RATE = 4
local GRAPH_BG_COLOR = {100, 100, 100}
local GRAPH_LABEL_COLOR = {255, 255, 255}

--[[
    Variables
--]]
local people = {}
local spawnTimer = 0
local spawnRateSlider = { value = 5, min = 0.1, max = 15 }
local stairwayBiasSlider = { value = 0.5, min = 0, max = 1 }
local guidanceCheckbox = { checked = false }

local numberOfPeopleData = {}
local averageWaitData = {}
local stairImbalanceData = {}
local sampleCount = 0

local guidanceSystemChoices = {
    STAIR_LEFT, STAIR_LEFT, STAIR_RIGHT, STAIR_RIGHT, STAIR_RIGHT, STAIR_LEFT
}

--[[
    Code
--]]
function spawnPerson()
    -- Choose a random spawn point.
    local spawnPointId = math.random(#SPAWN_POINT_COORDS)
    local spawnPointCoords = SPAWN_POINT_COORDS[spawnPointId]

    -- Choose a random stairway (1 = left, 2 = right)
    local stairId = math.random() > stairwayBiasSlider.value and 1 or 2
    -- If EGS is activated, use that instead.
    if guidanceCheckbox.checked then
        stairId = guidanceSystemChoices[spawnPointId]
    end

    -- Choose the appropriate door.
    local doorCoords = stairId == STAIR_LEFT and ROOM_DOOR_COORDS[spawnPointId][2] or ROOM_DOOR_COORDS[spawnPointId][1]

    -- If our spawn point is 4..6, we are in the bottom half.
    local inBottomHalf = spawnPointId >= 4

    -- Build the path the person will follow, starting with the door.
    local path = {doorCoords}

    -- If they're in the bottom half...
    if inBottomHalf then
        table.insert(path, {
            doorCoords[X],
            HALL_CORNER_COORDS[BOTTOM_HALL][LEFT_CORNER][Y]
        })
        -- If they're going to the left stairway...
        if stairId == LEFT_STAIR then
            -- Add the bottom hallway's left corner.
            table.insert(path, HALL_CORNER_COORDS[BOTTOM_HALL][LEFT_CORNER])
            -- Add an extra point outside the stairway door.
            table.insert(path, {
                HALL_CORNER_COORDS[BOTTOM_HALL][LEFT_CORNER][X],
                STAIR_DOOR_COORDS[LEFT_STAIR][STAIR_BOTTOM][Y]
            })
        else
            -- Otherwise they're going to the right stairway,
            --   so add the bottom hallway's right corner.
            table.insert(path, HALL_CORNER_COORDS[BOTTOM_HALL][RIGHT_CORNER])
        end
        -- Add the door of the stairway.
        table.insert(path, STAIR_DOOR_COORDS[stairId][STAIR_BOTTOM])
    else
        -- Add the Y of the top hallway.
        table.insert(path, {
            doorCoords[X],
            HALL_CORNER_COORDS[TOP_HALL][LEFT_CORNER][Y]
        })
        -- If they're going to the left stairway...
        if stairId == LEFT_STAIR then
            -- Add the top hallway's left corner.
            table.insert(path, HALL_CORNER_COORDS[TOP_HALL][LEFT_CORNER])
        else
            -- Otherwise they're going to the right stairway,
            --   so add the top hallway's right corner.
            table.insert(path, HALL_CORNER_COORDS[TOP_HALL][RIGHT_CORNER])
        end
        -- Add the door of the stairway.
        table.insert(path, STAIR_DOOR_COORDS[stairId][STAIR_TOP])
    end

    -- Add each point in the stairway's path to the exit.
    for i, coord in ipairs(STAIR_PATH_COORDS[stairId]) do
        table.insert(path, coord)
    end

    table.insert(people, {
        alive = true,
        image = PERSON_IMAGES[math.random(#PERSON_IMAGES)],
        x = spawnPointCoords[X],
        y = spawnPointCoords[Y],
        path = path,
        currentPoint = 1,
        o = inBottomHalf and (1/4 * TAU) or (3/4 * TAU),
        stairId = stairId
    })
end

function love.update(dt)
    local leftStairCount, rightStairCount = 0, 0
    for i, person in ipairs(people) do
        if person.alive then
            local x, y = person.x, person.y
            if x > 197 and x < 379 and y > 207 and y < 299 then
                leftStairCount = leftStairCount + 1
            elseif x > 813 and x < 972 and y > 278 and y < 390 then
                rightStairCount = rightStairCount + 1
            end
        end
    end

    local leftStairSpeed, rightStairSpeed = 1, 1
    if leftStairCount > 20 then
        leftStairSpeed = math.max(0.1, 1 - math.pow(leftStairCount-20, 2)/400)
    end
    if rightStairCount > 20 then
        rightStairSpeed = math.max(0.1, 1 - math.pow(rightStairCount-20, 2)/400)
    end

    for i, person in ipairs(people) do
        if person.alive then
            local target = person.path[person.currentPoint]
            local x, y = person.x, person.y
            local dx = target[X] - person.x
            local dy = target[Y] - person.y
            local d = math.sqrt(dx * dx + dy * dy)
            local o = math.atan2(dy, dx)

            local speed

            if x > 197 and x < 379 and y > 207 and y < 299 then
                speed = leftStairSpeed
            elseif x > 813 and x < 972 and y > 278 and y < 390 then
                speed = rightStairSpeed
            else
                if person.stairId == STAIR_LEFT then
                    speed = leftStairSpeed
                else
                    speed = rightStairSpeed
                end
            end

            person.x = person.x + dx / d * speed
            person.y = person.y + dy / d * speed

            if math.abs(dx) <= 2 and math.abs(dy) <= 2 then
                person.currentPoint = person.currentPoint + 1
                if person.currentPoint > #person.path then
                    person.alive = false
                end
            end
        end
    end

    -- Remove dead people from front of table.
    while #people > 0 and not people[1].alive do
        table.remove(people, 1)
    end

    spawnTimer = spawnTimer - dt
    if spawnTimer <= 0 then
        spawnPerson()
        spawnTimer = 1 / spawnRateSlider.value
    end

    suit.layout:reset(20, 720-160+50, 10, 10)

    suit.layout:push(suit.layout:row(0, 0))
        suit.Label('Spawn rate (people/sec)', {align='left'}, suit.layout:col(200, 20))
        suit.Slider(spawnRateSlider, suit.layout:col(160, nil))
        suit.Label(('%.02f'):format(spawnRateSlider.value), {align='right'}, suit.layout:col(40, nil))
    suit.layout:pop()

    suit.layout:push(suit.layout:row(nil, nil))
        suit.Label('Stairway bias (0=left, 1=right)', {align='left'}, suit.layout:row(200, 20))
        suit.Slider(stairwayBiasSlider, suit.layout:col(160, nil))
        suit.Label(('%.02f'):format(stairwayBiasSlider.value), {align='right'}, suit.layout:col(40, nil))
    suit.layout:pop()

    suit.layout:push(suit.layout:row(nil, nil))
        suit.Label('Activate guidance system', {align='left'}, suit.layout:row(200, 20))
        suit.Checkbox(guidanceCheckbox, suit.layout:col())
    suit.layout:pop()
end

function printRight(font, text, x, y)
    love.graphics.print(text, x - font:getWidth(text), y)
end

function graph(dataSet, x, y, w, h, expectedMax)
    love.graphics.push('all')
    love.graphics.setColor(GRAPH_BG_COLOR[1], GRAPH_BG_COLOR[2], GRAPH_BG_COLOR[3])
    love.graphics.rectangle("fill", x, y, w, h)

    local realMax = 0
    for i, data in ipairs(dataSet) do
        if data > realMax then
            realMax = data
        end
    end
    local max = realMax > expectedMax and realMax or expectedMax

    local barWidth = w / #dataSet
    for i, data in ipairs(dataSet) do
        local amount = data / max
        love.graphics.setColor(amount * 200, 255 - amount * 200, 20)
        love.graphics.rectangle("fill", x + w - i*barWidth, y + h - amount*h, barWidth, amount*h)
    end

    love.graphics.setColor(GRAPH_LABEL_COLOR[1], GRAPH_LABEL_COLOR[2], GRAPH_LABEL_COLOR[3])
    love.graphics.setFont(GRAPH_FONT)
    love.graphics.print('0', x+w+2, y+h-12)
    love.graphics.print(realMax, x+w+2, math.min(y+h-12-14, y+h-12-(realMax / max)*h))
    love.graphics.pop()
end

function love.draw()
    love.graphics.draw(FLOOR_IMAGE, 0, 0)

    local aliveCount = 0
    local leftStairCount = 0
    local rightStairCount = 0

    for i, person in ipairs(people) do
        if person.alive then
            aliveCount = aliveCount + 1
            local target = person.path[person.currentPoint]
            local dx = target[X] - person.x
            local dy = person.y - target[Y]
            local o = math.atan2(dy, dx)

            local x, y = person.x, person.y
            if x > 197 and x < 379 and y > 207 and y < 299 then
                leftStairCount = leftStairCount + 1
            elseif x > 813 and x < 972 and y > 278 and y < 390 then
                rightStairCount = rightStairCount + 1
            end

            love.graphics.push()
            love.graphics.translate(person.x, person.y)
            love.graphics.rotate(-o)
            love.graphics.scale(PERSON_SCALE, PERSON_SCALE)
            love.graphics.draw(person.image, -128, -128)
            love.graphics.pop()
        end
    end

    sampleCount = sampleCount + 1
    if sampleCount == SAMPLE_RATE then
        table.insert(numberOfPeopleData, 1, aliveCount)
        if #numberOfPeopleData > 20 then
            table.remove(numberOfPeopleData)
        end

        local stairImbalance
        if leftStairCount == 0 and rightStairCount == 0 then
            stairImbalance = 0.5
        else
            stairImbalance = math.max(leftStairCount / (leftStairCount + rightStairCount), rightStairCount / (leftStairCount + rightStairCount))
        end

        table.insert(stairImbalanceData, 1, math.floor(stairImbalance*100))
        if #stairImbalanceData > 20 then
            table.remove(stairImbalanceData)
        end

        local averageWait = math.floor((math.pow(math.max(0, rightStairCount-20), 3) + math.pow(math.max(0, leftStairCount-20), 3)) / (rightStairCount + leftStairCount) / 10)

        table.insert(averageWaitData, 1, averageWait)
        if #averageWaitData > 20 then
            table.remove(averageWaitData)
        end

        sampleCount = 0
    end

    love.graphics.push('all')
    do
        love.graphics.setColor(0, 0, 0)
        love.graphics.setFont(TITLE_FONT)
        love.graphics.print('Evacuation Simulator', 30, 20)
        love.graphics.setColor(180, 180, 180)
        love.graphics.setFont(TITLE_FONT)
        love.graphics.print('2016', TITLE_FONT:getWidth('Evacuation Simulator ') + 30, 20)

        love.graphics.setColor(10, 10, 10)
        love.graphics.rectangle('fill', 0, 720-160, 1280, 160)

        love.graphics.setColor(255, 255, 255)
        love.graphics.setFont(CONTROL_PANEL_FONT)
        love.graphics.print('Controls', 15, 720-160+15)

        love.graphics.setColor(255, 255, 255)
        love.graphics.setFont(LABEL_FONT)
        love.graphics.print('Number of people:', 700, 720-160+15)
        graph(numberOfPeopleData, 700, 720-160+15+30, 130, 100, 200)

        love.graphics.setColor(255, 255, 255)
        love.graphics.setFont(LABEL_FONT)
        love.graphics.print('Stair imbalance:', 900, 720-160+15)
        graph(stairImbalanceData, 900, 720-160+15+30, 130, 100, 100)

        love.graphics.setColor(255, 255, 255)
        love.graphics.setFont(LABEL_FONT)
        love.graphics.print('Average wait:', 1100, 720-160+15)
        graph(averageWaitData, 1100, 720-160+15+30, 130, 100, 100)
    end
    love.graphics.pop()

    suit.draw()
end

function love.mousepressed(x, y, button)
    if button == 1 then
        print(x..','..y)
    end
end

function love.textinput(t)
    -- forward text input to SUIT
    suit.textinput(t)
end

function love.keypressed(key)
    -- forward keypresses to SUIT
    suit.keypressed(key)
end
