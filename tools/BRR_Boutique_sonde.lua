-- Sonde TEMPORAIRE : charge chaque modele candidat de la Boutique et imprime ses mesures.
local CANDIDATS = {{"Ballerina",1,132021456717690},{"Ballerina",2,75983792852042},{"Ballerina",3,81269930750607},{"Ballerina",4,88721856095677},{"Ballerina",5,77919209524758},{"Ballerina",6,1045920745},{"Ballerina",7,426650827},{"Ballerina",8,5831560180},{"Ballerina",9,2110208734},{"Ballerina",10,14506025948},{"Bombardiro",1,91327024837680},{"Bombardiro",2,111138597903728},{"Bombardiro",3,117924360887083},{"Bombardiro",4,139363126210791},{"Bombardiro",5,13915553550},{"Bombardiro",6,7801752197},{"Bombardiro",7,8048673016},{"Bombardiro",8,9387706511},{"Bombardiro",9,4894410148},{"Bombardiro",10,6876570478},{"Cappuccino",1,138416013720223},{"Cappuccino",2,139476190777606},{"Cappuccino",3,130589530520250},{"Cappuccino",4,80869891423748},{"Cappuccino",5,116711431495967},{"Cappuccino",6,128293806084974},{"Cappuccino",7,24384568},{"Cappuccino",8,14227636328},{"Cappuccino",9,575714323},{"Cappuccino",10,106448409798280},{"Chimpanzini",1,134140230073093},{"Chimpanzini",2,83732984780551},{"Chimpanzini",3,125562008574484},{"Chimpanzini",4,86724865495774},{"Chimpanzini",5,138141667629120},{"Chimpanzini",6,95817281841993},{"Chimpanzini",7,110549308852539},{"Chimpanzini",8,11134802254},{"Chimpanzini",9,16455071827},{"Chimpanzini",10,3039924576},{"Lirili",1,77231614368559},{"Lirili",2,90717743642168},{"Lirili",3,100138257253783},{"Lirili",4,118261494949545},{"Lirili",5,113505154053595},{"Lirili",6,92139199335019},{"Lirili",7,107628757478592},{"Lirili",8,10587562672},{"Lirili",9,12874285330},{"Lirili",10,5184888914},{"Patapim",1,100538198930997},{"Patapim",2,112709347552350},{"Patapim",3,95929738286904},{"Patapim",4,121724230281477},{"Patapim",5,87700616475036},{"Patapim",6,110759128649311},{"Patapim",7,104111567366012},{"Patapim",8,129007491286589},{"Patapim",9,109340711807877},{"Patapim",10,83528951472353},{"Tralalero",1,111854862176457},{"Tralalero",2,83018340261801},{"Tralalero",3,113095126725171},{"Tralalero",4,129482668414941},{"Tralalero",5,128293704858194},{"Tralalero",6,102149043344287},{"Tralalero",7,133593545224523},{"Tralalero",8,132939399174162},{"Tralalero",9,108476156887875},{"Tralalero",10,79175375965402},{"TungSahur",1,138151705692565},{"TungSahur",2,137189209569355},{"TungSahur",3,83138270236341},{"TungSahur",4,112342985897325},{"TungSahur",5,128230179587698},{"TungSahur",6,71630473252028},{"TungSahur",7,116615563871570},{"TungSahur",8,116724607376773},{"TungSahur",9,109369994600403},{"TungSahur",10,94398976707691}}
local HS = game:GetService("HttpService")
local SUSPECT = {"require","getfenv","setfenv","loadstring","HttpService","MarketplaceService","TeleportService","InsertService","rbxassetid","string.reverse","getmetatable","fireclick","Kick("}
task.spawn(function()
  task.wait(8)
  for _, c in ipairs(CANDIDATS) do
    local ok, res = pcall(function() return game:GetObjects("rbxassetid://" .. c[3]) end)
    local r = { perso = c[1], rang = c[2], id = c[3], ok = ok }
    if ok and res and res[1] then
      local m = Instance.new("Model")
      for _, o in ipairs(res) do o.Parent = m end
      local parts, meshes, tris, scripts, suspects = 0, 0, 0, {}, {}
      for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") then parts += 1 end
        if d:IsA("MeshPart") or d:IsA("SpecialMesh") then meshes += 1 end
        if d:IsA("LuaSourceContainer") then
          local src = d.Source
          table.insert(scripts, d.ClassName .. ":" .. d.Name .. ":" .. #src)
          for _, s in ipairs(SUSPECT) do
            if string.find(src, s, 1, true) then table.insert(suspects, d.Name .. "->" .. s) end
          end
        end
      end
      local okb, cf, size = pcall(function() return m:GetBoundingBox() end)
      r.parts = parts; r.maillages = meshes; r.scripts = scripts; r.suspects = suspects
      r.taille = okb and string.format("%.1fx%.1fx%.1f", size.X, size.Y, size.Z) or "?"
      m:Destroy()
    else
      r.erreur = tostring(res)
    end
    print("[BRRBOUT] " .. HS:JSONEncode(r))
    task.wait(0.3)
  end
  print("[BRRBOUT] FIN")
end)
