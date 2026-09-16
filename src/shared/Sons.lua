-- Brainrot Royale : habillage sonore (« game feel »).
-- CHOIX D'ASSETS : uniquement des sons LIVRES AVEC LE CLIENT ROBLOX (rbxasset://sounds/...).
-- Verifie le 2026-09-16 dans le dossier d'installation de Studio
-- (Program Files (x86)/Roblox/Versions/version-93202a13414c4131/content/sounds) : ces 11 fichiers
-- sont presents chez tout joueur. Aucun identifiant de la bibliotheque en ligne n'est
-- utilise : rien a televerser, rien a faire moderer, aucune dependance au compte du createur.
-- Le son se joue CHEZ LE CLIENT : ce module est appele depuis GameClient / Hub, jamais du serveur.
local Sons = {}

local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local B = "rbxasset://sounds/"

-- nom d'evenement -> { asset, volume, vitesse de lecture }
Sons.banque = {
	selection    = { B .. "volume_slider.ogg",          0.35, 1.60 }, -- carte choisie dans la main
	pose         = { B .. "action_jump.mp3",            0.55, 1.25 }, -- carte posee dans l'arene
	mort         = { B .. "oof.ogg",                    0.45, 1.10 }, -- unite tuee
	tourDetruite = { B .. "impact_explosion_03.mp3",    0.80, 1.00 }, -- tour qui tombe
	victoire     = { B .. "action_get_up.mp3",          0.80, 1.20 },
	defaite      = { B .. "ouch.ogg",                   0.70, 0.80 },
	clic         = { B .. "volume_slider.ogg",          0.40, 1.00 }, -- bouton d'interface
	coffre       = { B .. "action_jump_land.mp3",       0.70, 1.15 }, -- coffre ouvert
	refus        = { B .. "action_falling.ogg",         0.45, 1.30 }, -- achat impossible
}

-- Joue un evenement. Retourne le Sound cree (ou nil si le nom est inconnu : un nom fautif ne doit
-- jamais casser la partie). Les sons sont crees dans SoundService puis nettoyes par Debris :
-- aucune fuite d'instance, meme si le joueur clique cent fois.
function Sons.jouer(nom, volumeRelatif)
	local e = Sons.banque[nom]
	if not e then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = "BRR_" .. nom
	s.SoundId = e[1]
	s.Volume = e[2] * (volumeRelatif or 1)
	s.PlaybackSpeed = e[3]
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 6)
	return s
end

return Sons
