--[[
    Various images assets
--]]
local FLOOR_IMAGE = love.graphics.newImage('assets/floor.png');
local PERSON_IMAGES = {
    love.graphics.newImage('assets/person1.png'),
    love.graphics.newImage('assets/person2.png'),
    love.graphics.newImage('assets/person3.png'),
    love.graphics.newImage('assets/person4.png')
}
local PERSON_SCALE = 1/8

--[[
    Coordinates
--]]
local X, Y, O = 1, 2, 3

local TAU = math.pi * 2
local N = 0/4 * TAU
local E = 1/4 * TAU
local S = 2/4 * TAU
local W = 3/4 * TAU

local SPAWN_POINT_COORDS = {
    {808, 113, S}, -- UA2120
    {610, 113, S}, -- UA2130
    {408, 120, S}, -- UA2140
    {810, 527, N}, -- UA2220
    {608, 520, N}, -- UA2230
    {406, 515, N}  -- UA2240
}

local ROOM_DOOR_COORDS = {
    {{878, 163, S}, {734, 164, S}}, -- UA2120
    {{681, 164, S}, {536, 164, S}}, -- UA2130
    {{483, 164, S}               }, -- UA2140
    {{885, 473, N}, {724, 473, N}}, -- UA2220
    {{688, 473, N}, {527, 472, N}}, -- UA2230
    {{490, 473, N}               }  -- UA2240
}

local TOP_HALL, BOTTOM_HALL = 1, 2
local LEFT_CORNER, RIGHT_CORNER = 1, 2

local HALL_CORNER_COORDS = {
    {{416, 212, S}, {953, 212, S}}, -- top
    {{397, 435, N}, {955, 435, N}}  -- bottom
}

local LEFT_STAIR, RIGHT_STAIR = 1, 2
local STAIR_TOP, STAIR_BOTTOM = 1, 2

local STAIR_DOOR_COORDS = {
    {{378, 229, W}, {378, 229, W}}, -- left
    {{952, 279, S}, {952, 394, N}}  -- right
}

local STAIR_PATH_COORDS = {
    {{334, 239, W}, {222, 238, S}, {221, 280, E}, {328, 280, E}},
    {{952, 303, W}, {933, 303, W}, {860, 317, S}, {840, 337, E}, {862, 356, E}, {932, 369, E}}
}

local PHASE_ROOM_DOOR = 1
local PHASE_HALLWAY = 2
local PHASE_STAIR_DOOR = 3
local PHASE_EXIT = 4
local PHASE_DEAD = 5

--[[
    Other constants
--]]


--[[
    Variables
--]]
local people = {}
local spawnTimer = 0.5

--[[
    Code
--]]
function spawnPerson()
    -- Choose a random spawn point.
    local spawnPointId = math.random(#SPAWN_POINT_COORDS)
    local spawnPointCoords = SPAWN_POINT_COORDS[spawnPointId]

    -- Choose a random door for the spawn point.
    local doorId = math.random(#ROOM_DOOR_COORDS[spawnPointId])
    local doorCoords = ROOM_DOOR_COORDS[spawnPointId][doorId]

    -- If our spawn point is 4..6, we are in the bottom half.
    local inBottomHalf = spawnPointId >= 4

    -- Choose a random stairway (1 = left, 2 = right)
    local stairId = math.random(2)

    -- Build the path the person will follow, starting with the door.
    local path = {doorCoords}

    -- If they're in the bottom half...
    if inBottomHalf then
        table.insert(path, {
            doorCoords[X],
            HALL_CORNER_COORDS[BOTTOM_HALL][LEFT_CORNER][Y],
            N
        })
        -- If they're going to the left stairway...
        if stairId == LEFT_STAIR then
            -- Add the bottom hallway's left corner.
            table.insert(path, HALL_CORNER_COORDS[BOTTOM_HALL][LEFT_CORNER])
            -- Add an extra point outside the stairway door.
            table.insert(path, {
                HALL_CORNER_COORDS[BOTTOM_HALL][LEFT_CORNER][X],
                STAIR_DOOR_COORDS[LEFT_STAIR][STAIR_BOTTOM][Y],
                W
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
            HALL_CORNER_COORDS[TOP_HALL][LEFT_CORNER][Y],
            S
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
        o = spawnPointCoords[O],
        path = path,
        currentPoint = 1
    })
end

function love.update(dt)
    for i, person in ipairs(people) do
        if person.alive then
            local target = person.path[person.currentPoint]
            local distanceX = target[X] - person.x
            local distanceY = target[Y] - person.y
            local distance = math.sqrt(distanceX * distanceX + distanceY * distanceY)
            local theta = math.atan(distanceY / distanceX)
            person.x = person.x + distanceX / distance
            person.y = person.y + distanceY / distance

            if math.abs(distanceX) <= 2 and math.abs(distanceY) <= 2 then
                person.currentPoint = person.currentPoint + 1
                if person.currentPoint > #person.path then
                    person.alive = false
                else
                    person.o = person.path[person.currentPoint][O]
                end
            end
        end
    end

    spawnTimer = spawnTimer - dt
    if spawnTimer <= 0 then
        spawnPerson()
        spawnTimer = 0.5
    end
end

function love.draw()
    love.graphics.setColor(255, 255, 255)
    love.graphics.draw(FLOOR_IMAGE, 0, 0)

    for i, person in ipairs(people) do
        if person.alive then
            love.graphics.setColor(255, 255, 255)
            love.graphics.push()
            love.graphics.translate(person.x, person.y)
            love.graphics.rotate(person.o)
            love.graphics.scale(PERSON_SCALE, PERSON_SCALE)
            love.graphics.draw(person.image, -128, -128)
            love.graphics.pop()
        end
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then
        spawnPerson()
    end
end
