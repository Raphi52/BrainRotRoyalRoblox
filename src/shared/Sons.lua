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

-- REGLAGES SONORES. Defaut mesure le 2026-09-20 : le jeu jouait musique et bruitages sans qu'AUCUN
-- ecran ne permette de les couper. Un joueur qui ecoute autre chose, ou qui joue a cote de
-- quelqu'un, n'avait qu'une solution : couper le son de tout l'appareil. Les deux se reglent
-- separement — on veut souvent garder les bruitages (ils PORTENT de l'information : une tour qui
-- tombe, une carte refusee) en coupant la musique.
Sons.reglages = { musique = true, bruitages = true }

-- Etat lisible par un ecran : « MUSIQUE : OUI ». Ecrit ICI pour que le banc puisse le verifier,
-- et pour que les deux ecrans (menu et partie) ne l'ecrivent pas chacun a leur facon.
function Sons.libelle(quoi)
	-- PIEGE DE LUA, vu a l'ecran (cap-son-partie.png du 2026-09-20) : ecrit « (quoi == 'musique')
	-- and Sons.reglages.musique or Sons.reglages.bruitages », le test retombe sur les BRUITAGES des
	-- que la musique vaut false. Le bouton affichait alors « MUSIQUE : OUI » alors qu'elle etait
	-- coupee. Un `if` ne peut pas mentir.
	local musique = quoi == "musique"
	local actif
	if musique then
		actif = Sons.reglages.musique
	else
		actif = Sons.reglages.bruitages
	end
	local nom = musique and "MUSIQUE" or "BRUITAGES"
	return nom .. " : " .. (actif and "OUI" or "NON")
end

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
	-- combat : un son par hausse des compteurs envoyes par le serveur (tirs, melee, zone)
	tir          = { B .. "volume_slider.ogg",          0.30, 2.20 }, -- projectile tire
	coupMelee    = { B .. "action_jump_land.mp3",       0.45, 1.40 }, -- coup au corps a corps
	explosion    = { B .. "impact_explosion_03.mp3",    0.35, 1.35 }, -- degat de zone
}

-- AMBIANCES BOUCLEES. Aucun des 11 fichiers livres avec le client n'est une musique : ce sont des
-- bruitages. On en tire un fond sonore continu (le « swim » ralenti donne une rumeur de foule).
-- Une vraie musique demanderait un identifiant de la bibliotheque en ligne, exclu par le choix
-- d'assets ci-dessus : c'est une decision a prendre par le createur, pas par ce module.
Sons.boucles = {
	hub    = { B .. "action_swim.mp3", 0.18, 0.55 },
	combat = { B .. "action_swim.mp3", 0.22, 0.75 },
}

-- Joue un evenement. Retourne le Sound cree (ou nil si le nom est inconnu : un nom fautif ne doit
-- jamais casser la partie). Les sons sont crees dans SoundService puis nettoyes par Debris :
-- aucune fuite d'instance, meme si le joueur clique cent fois.
-- `vitesseRelative` (facultatif) : multiplie la hauteur du son. C'est par la que le duel distingue
-- CE QUI M'ARRIVE de ce qui arrive en face — meme banque de sons, deux lectures differentes.
function Sons.jouer(nom, volumeRelatif, vitesseRelative)
	local e = Sons.banque[nom]
	if not e then
		return nil
	end
	-- Bruitages coupes : on ne cree meme pas l'objet son (un son a volume 0 reste charge et
	-- compte dans le mixage).
	if not Sons.reglages.bruitages then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = "BRR_" .. nom
	s.SoundId = e[1]
	s.Volume = e[2] * (volumeRelatif or 1)
	s.PlaybackSpeed = e[3] * (vitesseRelative or 1)
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 6)
	return s
end

-- LIMITEUR DE CADENCE (seau a jetons) : au plus `parSeconde` sons, pour qu'une grosse melee ne
-- sature pas le mixage. Rend une fonction `autorise(maintenant)` -> vrai/faux.
function Sons.limiteur(parSeconde)
	local jetons, avant = parSeconde, nil
	return function(maintenant)
		if avant then
			jetons = math.min(parSeconde, jetons + (maintenant - avant) * parSeconde)
		end
		avant = maintenant
		if jetons >= 1 then
			jetons = jetons - 1
			return true
		end
		return false
	end
end

-- Groupe de volume des ambiances : reglable a part des bruitages.
local groupe = nil
local function groupeAmbiance()
	if not groupe then
		groupe = Instance.new("SoundGroup")
		groupe.Name = "BRR_Ambiance"
		groupe.Volume = 1
		groupe.Parent = SoundService
	end
	return groupe
end

-- REGLER : `musique` et `bruitages` valent true, false, ou nil pour « ne change pas celui-la ».
-- La musique passe par le GROUPE de volume : une seule ligne coupe tout ce qui boucle, y compris
-- la boucle deja en cours. Rend l'etat obtenu, pour que l'ecran affiche ce qui s'est VRAIMENT
-- applique plutot que ce qu'il a demande.
function Sons.regler(musique, bruitages)
	if musique ~= nil then
		Sons.reglages.musique = musique == true
	end
	if bruitages ~= nil then
		Sons.reglages.bruitages = bruitages == true
	end
	groupeAmbiance().Volume = Sons.reglages.musique and 1 or 0
	return Sons.reglages
end

-- Lance l'ambiance `nom` (une seule a la fois : la precedente s'arrete). Nom inconnu -> nil.
local courante, courantNom = nil, nil
function Sons.boucle(nom)
	local e = Sons.boucles[nom]
	if not e then
		return nil
	end
	if courantNom == nom and courante then
		return courante
	end
	if courante then
		courante:Stop()
		courante:Destroy()
	end
	local s = Instance.new("Sound")
	s.Name = "BRR_Boucle_" .. nom
	s.SoundId = e[1]
	s.Volume = e[2]
	s.PlaybackSpeed = e[3]
	s.Looped = true
	local g = groupeAmbiance()
	-- Le groupe porte le reglage : une ambiance lancee APRES la coupure reste muette.
	g.Volume = Sons.reglages.musique and 1 or 0
	s.SoundGroup = g
	s.Parent = SoundService
	s:Play()
	courante, courantNom = s, nom
	return s
end

-- MONTEE DE TENSION : sous 60 s restantes, l'ambiance de combat accelere et monte (jusqu'a +30 %).
-- Rend le facteur applique (1 = aucune tension).
function Sons.tension(tempsRestant)
	local f = 1
	if tempsRestant and tempsRestant < 60 then
		f = 1 + 0.3 * (1 - math.max(tempsRestant, 0) / 60)
	end
	if courante and courantNom == "combat" then
		local e = Sons.boucles.combat
		courante.PlaybackSpeed = e[3] * f
		courante.Volume = e[2] * f
	end
	return f
end

return Sons
