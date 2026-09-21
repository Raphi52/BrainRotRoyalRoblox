-- L'ADVERSAIRE QUI NE JOUE PAS, en regles PURES.
--
-- Le defaut corrige : un joueur pouvait rester planté sans poser une seule carte. En face, on
-- attendait le chrono ENTIER — trois minutes — pour une victoire vide, sans duel. Rien dans le
-- jeu ne reconnaissait la situation : ni message, ni fin anticipee. C'est le pendant du quitteur
-- (src/shared/Abandon.lua) : partir est sanctionne, mais RESTER sans jouer ne l'etait pas, ce qui
-- en faisait la faille evidente.
--
-- CE QU'ON REFUSE DE FAIRE : accuser quelqu'un qui n'a pas de quoi jouer. Un joueur peut
-- legitimement ne rien poser s'il n'a pas assez d'elixir pour sa carte la moins chere — et en
-- debut de partie, attendre est meme la bonne decision. Le compteur ne tourne donc que quand
-- jouer etait POSSIBLE.
local Inactif = {}

Inactif.GRACE = 20        -- debut de partie : attendre son elixir n'est pas de l'inactivite
Inactif.SEUIL = 45        -- au-dela, on previent le joueur
Inactif.DELAI_FIN = 20    -- puis la partie s'arrete, au profit de celui qui joue

local function nombre(v)
	return tonumber(v) or 0
end

-- Le compteur ne tourne QUE si le joueur avait de quoi poser. Sans cette condition, on
-- sanctionnerait une jauge vide, c'est-a-dire le jeu lui-meme.
function Inactif.compteur(elixir, coutMin)
	return nombre(elixir) >= nombre(coutMin)
end

-- Temps ECOULE sans avoir joue. Si le joueur n'a jamais rien pose, on compte depuis le debut de
-- la partie — pas depuis zero, sinon un joueur inactif depuis le premier instant serait
-- eternellement « actif ».
function Inactif.silence(dernierePose, maintenant, debutPartie)
	local ref = dernierePose and nombre(dernierePose) or nombre(debutPartie)
	return math.max(0, nombre(maintenant) - ref)
end

-- Avant la fin de la grace, on ne regarde rien. `ecoule` est le temps de jeu depuis le coup
-- d'envoi : pendant le compte a rebours de depart, personne ne peut poser.
function Inactif.surveille(ecoulePartie)
	return nombre(ecoulePartie) >= Inactif.GRACE
end

function Inactif.suspect(silence, ecoulePartie)
	return Inactif.surveille(ecoulePartie) and nombre(silence) >= Inactif.SEUIL
end

-- Secondes restantes avant l'arret de la partie. nil tant que le joueur n'est pas suspect : on ne
-- brandit pas un compte a rebours a quelqu'un qui joue normalement.
function Inactif.resteAvantFin(silence, ecoulePartie)
	if not Inactif.suspect(silence, ecoulePartie) then
		return nil
	end
	return math.max(0, math.ceil(Inactif.SEUIL + Inactif.DELAI_FIN - nombre(silence)))
end

function Inactif.doitFinir(silence, ecoulePartie)
	local reste = Inactif.resteAvantFin(silence, ecoulePartie)
	return reste ~= nil and reste <= 0
end

-- CE QU'ON DIT A L'INACTIF. Il doit pouvoir se rattraper : une partie qui s'arrete sans
-- avertissement passe pour un bug, ou pour une deconnexion.
function Inactif.avertissement(reste)
	if reste == nil then
		return nil
	end
	return string.format("Joue une carte ! Sans action, la partie s'arrete dans %d s",
		math.max(0, math.floor(nombre(reste))))
end

-- CE QU'ON DIT A CELUI QUI JOUE. Il attendait sans comprendre : il croyait affronter quelqu'un.
function Inactif.texteAttente(silence, ecoulePartie)
	if not Inactif.suspect(silence, ecoulePartie) then
		return nil
	end
	return string.format("Ton adversaire ne joue plus depuis %d s", math.floor(nombre(silence)))
end

-- L'inactivite est traitee comme un ABANDON : rester planté pour epuiser le chrono est le meme
-- geste que partir, en plus couteux pour l'autre. Sans cela, il suffirait de ne rien faire pour
-- contourner la sanction du quitteur.
function Inactif.vautAbandon(adversaireHumain)
	return adversaireHumain == true
end

return Inactif
