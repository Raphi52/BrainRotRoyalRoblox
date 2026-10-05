-- SPRITES TELEVERSES (genere par tools/televerser_sprites.py, ne pas editer a la main).
-- Source de chaque image : tools/sprites/<nom>.png, dessinee par tools/sprites_coffres.py
-- (aucune ressource externe). Revise le choix « aucun asset a televerser » de Habillage.lua
-- pour les coffres : les cadres empiles etaient juges illisibles (2026-10-05).
-- Un nom absent rend nil : l'appelant garde alors son dessin en cadres.
local Sprites = {}

Sprites.IDS = {
}

function Sprites.image(nom)
	local id = Sprites.IDS[nom]
	if not id then
		return nil
	end
	return "rbxassetid://" .. id
end

return Sprites
