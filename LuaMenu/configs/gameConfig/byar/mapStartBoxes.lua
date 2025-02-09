local function pyPartition(s,p,left)
  if string.find(s,p,nil,true) then
    local startfind, endfind =  string.find(s,p,nil,true) 
    if left then
      return string.sub(s,1,startfind-1)
    else
      return string.sub(s,endfind+1)
    end
  else 
    return s
  end
end

local function lines(str)
  local t = {}
  local function helper(line) table.insert(t, line) return "" end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
end

function split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end


local function parseSpadsBoxLine(sbl)
    sbl = pyPartition(sbl,"#",true)
    if sbl == nil or sbl:len() < 10 then return nil end
    local mapName = pyPartition(sbl,".smf:",true) --Aberdeen3v3v3.smf
    local startdata = pyPartition(sbl,".smf:",false) --2|0 0 50 200;150 0 200 200
    local playercount = tonumber(pyPartition(startdata,"|",true))
    local boxes = {}
    local boxinfo = pyPartition(startdata,"|",false)
    for i,strbox in pairs(split(boxinfo, ";")) do
        boxes[i] = {}
        for j, position in pairs(split(strbox," ")) do
          boxes[i][j] = tonumber(position)/200.0
        end
    end
    return mapName, playercount, boxes
end

--parseSpadsBoxLine("Aetherian Void 1.7.smf:4|0 0 80 80;120 120 200 200;0 120 80 200;120 0 200 80\n") --this is a unit test

-- spads style boxen: 	!addBox <left> <top> <right> <bottom> [<teamNumber>] - adds a new start box (0,0 is top left corner, 200,200 is bottom right corner)
-- make a table for each mapname
local savedBoxesFilename = LUA_DIRNAME .. "configs/gameConfig/byar/savedBoxes.dat" --taken from spads
local savedBoxesSpads =  VFS.LoadFile(savedBoxesFilename)
local singleplayerboxes = {}

local savedBoxes = {}
local numBoxes = 0
if savedBoxesSpads then
	local fileLines = lines(savedBoxesSpads)
	for i, line in ipairs(fileLines) do
    local mapname, playercount, boxes = parseSpadsBoxLine(line)
    --Spring.Echo("Start boxes parsed for",mapname,boxes,line,#savedBoxes)
    if mapname ~= nil then
        numBoxes = numBoxes + 1
        if savedBoxes[mapname] then
          savedBoxes[mapname][playercount] = boxes
          
          --Spring.Echo("updated existing",#savedBoxes,#boxes,playercount)
          
          --table.insert(savedBoxes[mapname],boxes,playercount)
        else
          --table.insert(savedBoxes,{playercount = boxes},mapname)
          savedBoxes[mapname] = {}
          savedBoxes[mapname][playercount] = boxes
          
          --Spring.Echo("added new entry",#savedBoxes,#boxes,playercount)
        end
    end
  end
end


Spring.Log("mapStartBoxes",LOG.INFO,"Parsed ",numBoxes, " start boxes from",savedBoxesFilename)

  
-- rules for boxes selection:
-- if there is a box set of the number of allyteams, use that
-- if there is no box set for the number of allyteams, but there is one that is larger, then use that
-- if there is no box set for the number of allyteams, but there is one that is smaller, then use that and blank the rest
  
local function selectStartBoxesForAllyTeamCount(startboxes, allyteamcount) 
  if startboxes == nil then return nil end
  local mystartboxes = nil
  local closestlarger = 10000
  local closestsmaller = 0
  for i, boxset in pairs(startboxes) do
    if i == allyteamcount then 
      Spring.Log("mapStartBoxes",LOG.INFO,"Found exact boxset for allyteamcount ",allyteamcount)
      return boxset 
    end
    if i > allyteamcount and i < closestlarger then 
      closestlarger = i
    end
    if i < allyteamcount and i > closestsmaller then
      closestsmaller = i
    end
  end
  if closestlarger < 10000 then
    Spring.Log("mapStartBoxes",LOG.INFO,"Found larger boxset ",closestlarger ," for allyteamcount ",allyteamcount)
    return startboxes[closestlarger]
  end
  if closestsmaller > 0 then
    Spring.Echo("Found smaller boxset ",closestsmaller, " for allyteamcount", allyteamcount)
    return startboxes[closestsmaller]
  end
  return nil
end

local function makeAllyTeamBox(startboxes, allyteamindex) 
    -- -- spads style boxen: 	!addBox <left> <top> <right> <bottom> [<teamNumber>] - adds a new start box (0,0 is top left corner, 200,200 is bottom right corner)
    --  startrectbottom=1;
    --  startrectleft=0;
    --  startrecttop=0.75;
    --  startrectright=1;
    local allyteamtable = {
        numallies = 0,
      }
    if startboxes and startboxes[allyteamindex + 1] then
      if startboxes[allyteamindex + 1].spadsSizes then
       local spadsSizes = startboxes[allyteamindex + 1].spadsSizes
       Spring.Echo("Skirmish: startbox for team:",allyteamindex, "is", spadsSizes.left, spadsSizes.top, spadsSizes.right, spadsSizes.bottom)
        allyteamtable = {
          numallies = 0,
          startrectleft  = spadsSizes.left/200,
          startrecttop   = spadsSizes.top/200,
          startrectright = spadsSizes.right/200,
          startrectbottom= spadsSizes.bottom/200,
        }
      else
        allyteamtable = {
          numallies = 0,
          startrectleft  = startboxes[allyteamindex + 1][1],
          startrecttop   = startboxes[allyteamindex + 1][2],
          startrectright = startboxes[allyteamindex + 1][3],
          startrectbottom= startboxes[allyteamindex + 1][4],
        }
      end
    end
    return allyteamtable
end

-- how about some more helpers?
local function initCustomBox(mapName)
    singleplayerboxes = {}
end

local function addBox(left,top, right, bottom, allyTeam) --in spads order
  initCustomBox()
  singleplayerboxes[allyTeam] = {left,top,right,bottom}
  -- if online then: function Interface:AddStartRect(allyNo, left, top, right, bottom)
end

local function removeBox(allyTeam)
  initCustomBox()
  if singleplayerboxes[allyTeam] then
    singleplayerboxes[allyTeam] = nil
  end
end

local function clearBoxes()
  initCustomBox()
  singleplayerboxes = {}
end

local function getBox(allyTeam)
  if savedBoxes[mapName] == nil then
    initCustomBox(mapName)
  end
  if singleplayerboxes then
    return singleplayerboxes[allyTeam]
  else
    local defaultboxes =  selectStartBoxesForAllyTeamCount(mapName,2)
    if defaultboxes then  
      return defaultboxes[allyTeam]
    end
  end
  return nil
end

return {
  savedBoxes = savedBoxes,
  selectStartBoxesForAllyTeamCount = selectStartBoxesForAllyTeamCount,
  makeAllyTeamBox = makeAllyTeamBox,
  getBox = getBox,
  clearBoxes = clearBoxes,
  removeBox = removeBox,
  addBox = addBox,
  singleplayerboxes = singleplayerboxes,
}

--v2 table layout:
--[[
savedboxes = {
  ["my garbage map"] = {
    "2" = {
      team1 = {
        top = 0.0,
        left = 0.0,
        right = 1.0,
        bottom = 1.0,
        }
      team2 = {
        top = 0.0
      }
    }
  }
}

]]--


--['mapname'] = {2={0={}}}

--[[
for each playercount:
  

# Warning, this file is updated automatically by SPADS.
# Any modifications performed on this file while SPADS is running will be automatically erased.
  
#?mapName:nbTeams|boxes
Aberdeen3v3v3.smf:2|0 0 50 200;150 0 200 200
Aberdeen6v6_Fix.smf:2|0 0 50 200;150 0 200 200
Aetherian Void 1.7.smf:2|0 0 70 200;130 0 200 200
Aetherian Void 1.7.smf:4|0 0 80 80;120 120 200 200;0 120 80 200;120 0 200 80
Akilon Wastelands - v18.smf:2|0 0 64 64;136 136 200 200
AlphaSiegeDry 2.2.smf:2|0 0 26 200;174 0 200 200
Altair_Crossing_v3.smf:2|0 0 50 200;150 0 200 200
Altored Divide Bar Remake 1.3.smf:2|0 0 200 74;0 126 200 200
Altored Divide Bar Remake 1.42.smf:2|0 0 200 70;0 130 200 200
Altored Divide Bar Remake 1.5.smf:2|0 0 200 40;0 160 200 200
Altored Divide Bar Remake 1.55.smf:2|0 0 200 40;0 160 200 200
Archers_Valley_v6.smf:2|0 0 40 200;160 0 200 200
Avalanche-v2.smf:2|0 0 46 46;154 154 200 200
Barren 2.smf:2|0 0 200 40;0 160 200 200
BlackStar.smf:2|0 0 200 70;0 130 200 200
BlackStar_v2.smf:2|0 0 52 200;148 0 200 200
Boulder_Beach_V1.smf:2|0 0 30 200;170 0 200 200
Calamity 1.1.smf:2|0 0 200 40;0 160 200 200
Centerrock Remake 1.2.smf:2|0 0 80 80;120 120 200 200
Cervino v1.smf:2|0 0 50 200;150 0 200 200
Colorado_v1.smf:2|0 0 40 200;160 0 200 200
Comet Catcher Redux.smf:2|0 0 200 40;0 160 200 200
Comet Catcher Remake 1.8.smf:2|0 0 34 200;166 0 200 200
DSDR 3.95.smf:2|0 0 40 200;160 0 200 200
DSDR 3.96.smf:2|0 0 30 200;170 0 200 200
DSDR 3.98.smf:2|0 0 58 200;142 0 200 200
DWorld_V3.smf:2|0 0 200 54;0 146 200 200
DeltaSiegeDry.smf:2|0 0 56 200;144 0 200 200
Desert 3.25.smf:2|0 0 46 200;154 0 200 200
DesertTriad.smf:2|0 0 46 200;154 0 200 200
DigSite.smf:2|0 0 200 40;0 160 200 200
Downs_of_Destruction_Fix.smf:2|0 140 60 200;140 0 200 60
Emain Macha v3.smf:2|0 0 200 22;0 178 200 200
Eye of Horus v13.smf:2|0 0 200 34;0 166 200 200
FolsomDamDeluxeV4.smf:2|0 0 38 200;162 0 200 200
FolsomDam_V2.smf:2|0 0 20 200;180 0 200 200
Gecko Isle 1.1.smf:2|0 0 200 30;0 170 200 200
Gehenna Rising 3.smf:2|0 0 60 60;140 140 200 200
Gehenna Rising 3.smf:4|0 0 60 60;140 140 200 200;0 140 60 200;140 0 200 60
Green_Fields_fix.smf:2|0 0 200 40;0 160 200 200
Hotlips_Redux_V2.smf:2|0 0 40 200;160 0 200 200
Ibex v1.smf:2|0 0 40 200;160 0 200 200
Incandescence 2.2.smf:2|0 0 80 80;120 120 200 200
Into Battle v4.smf:2|0 150 50 200;150 0 200 50
John's-pond_rc.smf:2|0 0 200 30;0 170 200 200
KnockoutR 1.5.smf:2|16 50 44 150;156 50 184 150
KnockoutR 1.5.smf:4|16 50 44 150;156 50 184 150;50 16 150 44;50 156 150 184
Kolmogorov.smf:2|0 116 84 200;116 0 200 84
Koom Gorge 3vs3 edition1.2.smf:2|0 0 70 200;130 0 200 200
Koom Valley V2.smf:2|0 0 50 200;150 0 200 200
Mescaline_V2.smf:2|0 0 26 200;174 0 200 200
Metal_Plate_22x22.smf:2|0 0 200 40;0 160 200 200
MoonQ20XR2 2.5.smf:2|0 0 58 200;142 0 200 200
Neurope_a7_v3.smf:2|0 0 30 200;160 0 200 200
Neurope_a7_v3.smf:3|0 0 30 200;160 0 200 200;60 170 140 200
Neurope_a7_v3.smf:4|0 0 30 200;160 0 200 200;60 170 140 200;60 40 140 110
Nuclear Winter v3.smf:2|0 0 50 200;150 0 200 200
Otago 1.4.smf:2|0 0 60 200;140 0 200 200
Painted Badlands 1.0.smf:2|0 0 200 80;0 120 200 200
Pentos_V1.smf:2|0 0 64 200;136 0 200 200
Quicksilver Remake 1.22.smf:2|0 110 90 200;110 0 200 90
Quicksilver Remake 1.24.smf:2|0 130 200 200;0 0 200 70
Red Comet Remake 1.7.smf:2|0 0 40 200;160 0 200 200
Red Comet Remake 1.8.smf:2|0 0 46 200;154 0 200 200
Riverdale Remake 1.4.smf:2|0 0 200 40;0 160 200 200
SapphireShores_V2.2.smf:2|0 0 30 200;170 0 200 200
Seth's Ravine 3.1.smf:2|0 0 60 200;140 0 200 200
Simple 6 Way 1.2-KotH.smf:2|0 0 200 70;0 130 200 200
Small Supreme Battlefield V2 Special v3.smf:2|0 0 60 200;140 0 200 200
Small Supreme Islands V2.smf:2|0 140 60 200;140 0 200 60
Small_Supreme_Battlefield_V3.smf:2|0 126 74 200;126 0 200 74
SpeedMetal BAR V2.smf:2|0 0 40 200;160 0 200 200
Stronghold V4.smf:2|0 0 200 50;0 150 200 200
Stronghold V4.smf:4|0 0 50 50;150 150 200 200;0 150 50 200;150 0 200 50
Supreme_Crossing_V1.smf:2|0 126 74 200;126 0 200 74
Supreme_Lake_Dry_V5.smf:2|0 0 80 200;120 0 200 200
TMA20X 1.8.smf:2|0 0 200 70;0 130 200 200
TMA20XR 2.1.smf:2|0 0 200 80;0 120 200 200
Tabula-v4.smf:2|0 0 30 200;170 0 200 200
Tabula-v6.1.smf:2|0 0 60 200;140 0 200 200
Tabula-v6.smf:2|0 0 200 40;0 160 200 200
Tabula_Flooded_v04.smf:2|0 0 40 200;160 0 200 200
Talus-wet-v3.smf:2|0 0 30 200;170 0 200 200
Talus_v2.smf:2|0 0 30 200;170 0 200 200
Tempest Dry.smf:2|0 0 200 52;0 148 200 200
Tempest.smf:2|0 0 200 52;0 148 200 200
Tetrad_V2.smf:2|0 0 44 200;156 0 200 200
Tetrad_V2.smf:4|0 0 50 50;150 150 200 200;0 150 50 200;150 0 200 50
The river Nix 20.smf:2|0 0 40 200;160 0 200 200
Throne Acidic.smf:2|0 0 64 200;136 0 200 200
Throne Acidic.smf:4|0 0 80 80;120 120 200 200;0 120 80 200;120 0 200 80
Titan v3.1.smf:2|0 0 40 200;160 0 200 200
TitanDuel.smf:2|0 0 200 40;0 160 200 200
Trefoil Remake 2.19.smf:2|0 0 50 200;150 0 200 200
Trefoil Remake 2.20.smf:2|0 0 56 200;144 0 200 200
Trefoil Remake 2.20.smf:3|0 0 56 200;144 0 200 200;80 140 120 200
Tropical-v2.smf:2|0 0 200 56;0 144 200 200
Tropical.smf:2|0 0 200 60;0 140 200 200
Tumult.smf:2|0 0 200 40;0 160 200 200
Twin Lakes Park 1.smf:2|0 0 50 200;150 0 200 200
Valles_Marineris_v2.smf:2|0 0 34 200;166 0 200 200
Vantage v1.1.smf:2|0 0 200 50;0 150 200 200
Zed 2.3 - MexesFix.smf:2|0 0 200 40;0 160 200 200
hotstepper.smf:2|0 0 44 200;156 0 200 200
hotstepper.smf:4|0 0 46 46;154 154 200 200;0 154 46 200;154 0 200 46
]]--
