-- Plugin de test temporaire (copie de test seulement, marqueur BRR_AUTOTEST) :
-- 1) Run (serveur seul, bot contre bot)   2) Play (un vrai client local)
local RunService = game:GetService("RunService")
local rs = game:GetService("ReplicatedStorage")
if RunService:IsEdit() and rs:FindFirstChild("BRR_AUTOTEST") then
	task.delay(5, function()
		-- GARDE ANTI-DOUBLE LANCEMENT : depuis que chaque run depose SA copie du plugin (nom unique
		-- par bureau cache), plusieurs copies peuvent etre chargees par le meme Studio. Sans ce
		-- marqueur, chacune appellerait Play et la session serait relancee en cours de capture.
		-- Le test et la pose du marqueur ne rendent jamais la main entre eux : pas de course.
		if rs:FindFirstChild("BRR_AUTORUN_LANCE") then
			return
		end
		local marqueur = Instance.new("BoolValue")
		marqueur.Name = "BRR_AUTORUN_LANCE"
		marqueur.Parent = rs
		local ok, err = pcall(function()
			local sts = game:GetService("StudioTestService")
			local joueurs = tonumber((rs:FindFirstChild("BRR_JOUEURS") or {}).Value or 1) or 1
			if rs:FindFirstChild("BRR_RUN") then
				-- Mode RUN : aucun joueur, les deux camps sont tenus par le bot. C'est le seul moyen
				-- de juger une partie ENTIERE : en mode Play, le client de test rend la main vers
				-- 32 s et son camp cesse d'attaquer.
				print("[BRR] plugin : Run (bot contre bot)")
				local r = sts:ExecuteRunModeAsync({ brr = true })
				print("[BRR] plugin : Run termine -> " .. tostring(r))
			elseif joueurs > 1 then
				-- DEUX JOUEURS : ExecuteMultiplayerTestAsync(nombre, args) lance un serveur et N
				-- clients (doc Roblox, StudioTestService). ExecutePlayModeAsync n'en lance qu'un.
				print("[BRR] plugin : test multijoueur a " .. joueurs .. " joueurs")
				local r = sts:ExecuteMultiplayerTestAsync(joueurs, { brr = true })
				print("[BRR] plugin : test multijoueur termine -> " .. tostring(r))
			else
				print("[BRR] plugin : Play")
				local r = sts:ExecutePlayModeAsync({ brr = true })
				print("[BRR] plugin : Play termine -> " .. tostring(r))
			end
		end)
		if not ok then
			print("[BRR] plugin : Play impossible -> " .. tostring(err))
		end
	end)
end
