-- DUEL : les regles du FACE-A-FACE humain, en fonctions PURES (aucune API Roblox ici).
--
-- Pourquoi ce module existe. Trois moments du duel etaient decides a la main dans le serveur, et
-- aucun n'etait verifiable hors Studio :
--  1. LE COUP D'ENVOI. Le premier arrive dans le serveur reserve lancait la partie tout seul :
--     chrono, elixir et robot tournaient pendant que l'autre joueur etait encore en teleportation.
--  2. L'ABANDON. Partir en pleine partie rendait le camp au robot : l'adversaire finissait contre
--     une machine, et le partant echappait a sa defaite.
--  3. LA REVANCHE. « Rejouer » relancait tout de suite, effacant l'ecran de fin de l'autre.
-- Ecrites ici, ces trois regles se verifient par tools/test_pvp.py.
local Duel = {}

Duel.ATTENTE_ADVERSAIRE_MAX = 30 -- secondes d'attente avant de jouer sans lui
Duel.COMPTE_A_REBOURS = 3        -- « 3, 2, 1 » donne aux DEUX camps en meme temps

-- COUP D'ENVOI. Rend (gele, phase, secondes).
--   estServeurDeMatch : un serveur reserve a UN duel (sur un serveur hub, rien n'est gele)
--   joueurs           : nombre de camps tenus par un humain
--   ecouleAttente     : secondes depuis l'ouverture du serveur
--   ecouleCompte      : secondes depuis que les deux camps sont pris (nil si pas encore)
-- `gele` = la simulation ne doit PAS tourner : ni chrono, ni elixir, ni robot.
function Duel.attente(estServeurDeMatch, joueurs, ecouleAttente, ecouleCompte)
	if not estServeurDeMatch then
		return false
	end
	if (joueurs or 0) >= 2 then
		local reste = Duel.COMPTE_A_REBOURS - (ecouleCompte or 0)
		if reste > 0 then
			return true, "depart", math.ceil(reste)
		end
		return false
	end
	local reste = Duel.ATTENTE_ADVERSAIRE_MAX - (ecouleAttente or 0)
	if reste > 0 then
		return true, "adversaire", math.ceil(reste)
	end
	return false -- personne n'est venu : on joue quand meme (contre le robot)
end

-- ABANDON : un depart ne donne la victoire a l'autre que si l'autre est un HUMAIN et que la
-- partie court encore. Contre le robot, partir reste sans consequence.
function Duel.forfait(partieFinie, camp, adversaireHumain)
	if partieFinie or not camp or not adversaireHumain then
		return false
	end
	return true
end

-- REVANCHE : contre le robot, un clic suffit. Contre un humain, il faut les DEUX.
-- RELANCER ALORS QUE L'AUTRE EST COUPE. Mesure le 2026-09-21 en suivant le chemin de relance :
-- il regardait « y a-t-il quelqu'un en face MAINTENANT ». Or un joueur deconnecte a son camp
-- RESERVE (il a 45 s pour revenir) mais n'est plus occupant. Sa reservation ne pesait donc rien :
-- le clic de celui qui restait relancait une partie neuve, ce qui effacait la partie ET la
-- reservation de l'absent — une nouvelle partie demarree par UN SEUL, contre quelqu'un qui ne
-- pouvait meme pas valider puisqu'il etait deconnecte.
function Duel.peutRelancer(adversaireEnReprise)
	return adversaireEnReprise ~= true
end

function Duel.texteRelanceBloquee()
	return "Ton adversaire s'est deconnecte : on attend son retour"
end

-- REFUSER, ET NE PAS ATTENDRE INDEFINIMENT. Mesure le 2026-09-21 : celui qui demandait la
-- revanche restait sur « En attente de l'adversaire... » SANS AUCUNE LIMITE, et l'autre n'avait
-- aucun moyen de dire non — il ne pouvait que partir. Du cote de celui qui attend, « il reflechit »
-- et « il ne veut pas » se ressemblaient donc exactement, et l'attente ne finissait jamais.
Duel.DELAI_REVANCHE = 20 -- assez pour lire l'ecran de fin, trop court pour bloquer quelqu'un

function Duel.resteRevanche(depuis, maintenant)
	if not depuis then
		return nil
	end
	return math.max(0, math.ceil(depuis + Duel.DELAI_REVANCHE - (tonumber(maintenant) or 0)))
end

function Duel.revancheExpiree(depuis, maintenant)
	local reste = Duel.resteRevanche(depuis, maintenant)
	return reste ~= nil and reste <= 0
end

-- Un refus se DIT, il ne se devine pas. C'est aussi ce qui libere l'autre tout de suite, au lieu
-- de le laisser regarder un compte a rebours qu'il sait deja perdu.
function Duel.texteRefus()
	return "Ton adversaire ne veut pas de revanche"
end

function Duel.texteAttenteRevanche(reste)
	if reste == nil then
		return "En attente de l'adversaire..."
	end
	return string.format("En attente de l'adversaire... %d s", math.max(0, math.floor(reste)))
end

-- REVANCHE DEMANDEE, PUIS L'AUTRE S'EN VA. Mesure le 2026-09-21 en relisant l'ecran de fin : le
-- bouton passait tout seul de « En attente de l'adversaire... » a « Rejouer », sans un mot. Deux
-- consequences, toutes deux silencieuses :
--   - on croyait que son clic n'avait pas fonctionne ;
--   - la demande restait enregistree cote serveur, donc le clic suivant relancait aussitot une
--     partie CONTRE LE ROBOT, alors qu'on voulait sa revanche contre LUI.
-- Une revanche perdue doit se DIRE. C'est le contraire d'une attente : il n'y a plus personne.
function Duel.revanchePerdue(moiDemande, adversaireHumain)
	return moiDemande == true and adversaireHumain ~= true
end

function Duel.texteRevanchePerdue()
	return "Ton adversaire est parti — la prochaine partie sera contre le robot"
end

-- Libelle du bouton de fin, dans les quatre situations possibles. Le rendre PUR permet de verifier
-- au banc qu'aucune d'elles ne laisse un bouton menteur.
-- `refus` : l'adversaire a dit non. `reste` : secondes restantes avant que la demande expire.
function Duel.texteBouton(adversaireHumain, moiDemande, luiDemande, refus, reste)
	if refus == true then
		return "Jouer contre le robot" -- il a dit non : ce ne sera pas le meme duel
	end
	if Duel.revanchePerdue(moiDemande, adversaireHumain) then
		return "Jouer contre le robot" -- on ne reecrit pas « Rejouer » : ce ne sera pas le meme duel
	end
	if adversaireHumain ~= true then
		return "Rejouer"
	end
	if not moiDemande then
		return "Revanche"
	end
	if luiDemande then
		return "C'est reparti !"
	end
	return Duel.texteAttenteRevanche(reste)
end

function Duel.revanchePrete(adversaireHumain, moiDemande, luiDemande)
	if not moiDemande then
		return false
	end
	if not adversaireHumain then
		return true
	end
	return luiDemande == true
end

-- UN DUEL ENTRE AMIS NE COMPTE PAS AU CLASSEMENT. Defaut mesure le 2026-09-21 : la donnee transportee
-- vers le serveur d'un duel prive ne portait QUE le mode « niveaux egalises ». Un duel prive
-- ordinaire etait donc indiscernable d'une partie classee, et rapportait des trophees. D'ou la faille
-- classique de tout classement : deux amis creent un duel prive, l'un abandonne aussitot, l'autre
-- empoche les trophees — puis on inverse les roles. Le classement, qui sert aussi a l'appariement,
-- se gonflait sans qu'aucun inconnu n'ait jamais ete affronte.
-- C'est la regle du genre pour les « parties amicales » : on joue pour le plaisir, pas pour le rang.
Duel.LIBELLE_AMICAL = "DUEL ENTRE AMIS — ne compte pas au classement"

function Duel.compteAuClassement(egalise, entreAmis)
	return egalise ~= true and entreAmis ~= true
end

-- Ce qu'on affiche en partie : le mode egalise prime (il dit AUSSI que ca ne compte pas), sinon le
-- duel amical, sinon rien.
function Duel.libelleHorsClassement(libelleEgalise, entreAmis)
	if libelleEgalise then
		return libelleEgalise
	end
	return entreAmis == true and Duel.LIBELLE_AMICAL or nil
end

-- CE QUE MET EN JEU UN DUEL ENTRE AMIS. Le panneau n'en disait rien : un duel entre amis ne
-- rapporte NI trophees NI coffre (Duel.compteAuClassement), et « NIVEAUX EGALISES » met toutes
-- les cartes des deux camps au meme niveau (Egalise.NIVEAU). Dit AVANT de lancer, pas apres.
function Duel.texteAide(egalise, niveau)
	local t = "Pour le plaisir : ni trophees ni coffre en jeu."
	if egalise then
		return t .. " Toutes les cartes des deux camps au niveau " .. tostring(niveau) .. "."
	end
	return t .. " Chacun joue avec ses propres niveaux."
end

return Duel
