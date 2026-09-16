-- Plugin TEMPORAIRE : charge les modeles retenus (tools/boutique/choix.json) et imprime leur
-- GEOMETRIE seule en JSON dans le journal de Studio. Aucun script n'est lu ni recopie : build.py
-- reconstruit les pieces a partir de ces mesures. Un plugin ne peut pas ecrire de fichier, d'ou
-- le passage par le journal.
local CHOIX = __CHOIX__
local HS = game:GetService("HttpService")

local function v3(v) return { v.X, v.Y, v.Z } end
local function c3(c) return { c.R, c.G, c.B } end
local function cf(c) return { c:GetComponents() } end

local function lire(obj, props)
	local r = {}
	for _, p in ipairs(props) do
		local ok, val = pcall(function() return obj[p] end)
		if ok then
			local t = typeof(val)
			if t == "Vector3" then r[p] = v3(val)
			elseif t == "Color3" then r[p] = c3(val)
			elseif t == "CFrame" then r[p] = cf(val)
			elseif t == "EnumItem" then r[p] = val.Name
			elseif t == "string" or t == "number" or t == "boolean" then r[p] = val
			end
		end
	end
	return r
end

task.spawn(function()
	task.wait(8)
	for perso, id in pairs(CHOIX) do
		local ok, res = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
		if not ok then
			print("[BRRMOD] " .. HS:JSONEncode({ perso = perso, erreur = tostring(res) }))
			continue
		end
		local m = Instance.new("Model")
		for _, o in ipairs(res) do o.Parent = m end
		local pivot = m:GetBoundingBox()
		local pieces, ignores = {}, {}
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				local base = lire(d, { "ClassName", "Size", "Color", "Material", "Transparency", "Reflectance", "MeshId", "TextureID", "InitialSize", "MeshSize", "Shape" })
				base.CFrame = cf(pivot:ToObjectSpace(d.CFrame))
				if d:IsA("UnionOperation") or d:IsA("NegateOperation") then
					table.insert(ignores, d.ClassName .. ":" .. d.Name)
				end
				base.enfants = {}
				for _, e in ipairs(d:GetChildren()) do
					if e:IsA("SpecialMesh") then
						table.insert(base.enfants, lire(e, { "ClassName", "MeshType", "MeshId", "TextureId", "Scale", "Offset", "VertexColor" }))
					elseif e:IsA("SurfaceAppearance") then
						table.insert(base.enfants, lire(e, { "ClassName", "ColorMap", "NormalMap", "MetalnessMap", "RoughnessMap", "AlphaMode" }))
					elseif e:IsA("Decal") then
						table.insert(base.enfants, lire(e, { "ClassName", "Texture", "Face", "Transparency" }))
					end
				end
				table.insert(pieces, base)
			end
		end
		local _, taille = m:GetBoundingBox()
		print("[BRRMOD] " .. HS:JSONEncode({ perso = perso, id = id, taille = v3(taille), n = #pieces, ignores = ignores }))
		for i, p in ipairs(pieces) do
			print("[BRRMODP] " .. HS:JSONEncode({ perso = perso, i = i, p = p }))
		end
		m:Destroy()
		task.wait(0.3)
	end
	print("[BRRMOD] FIN")
end)
