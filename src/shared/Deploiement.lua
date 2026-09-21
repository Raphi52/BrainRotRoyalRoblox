-- DEPLOIEMENT : le temps qu'une unite met a etre operationnelle apres sa pose.
--
-- Defaut lu dans le code : `addEntity` posait `e.cooldown = 0`, et rien n'empechait une unite de
-- se deplacer des sa premiere image. Une carte posee AGISSAIT donc instantanement. Trois
-- consequences, toutes mauvaises :
--   * aucun contre-jeu a la pose — poser une unite au contact d'un ennemi le frappe avant qu'il
--     puisse reagir, et l'adversaire ne peut rien y faire ;
--   * le jeu MENT a l'oeil — l'animation d'arrivee dure 0,45 s (l'unite tombe du ciel, touche le
--     sol vers 0,25 s, rebondit), et pendant tout ce temps elle frappait deja. Une unite qui
--     attaque alors qu'elle est encore en l'air, c'est ce que le joueur voit ;
--   * l'invulnerabilite de pose (Statuts.INVULN_POSE) protegeait une unite qui, elle, pouvait
--     agir : la protection ne jouait que dans un sens.
--
-- La duree retenue est celle de l'ANIMATION D'ARRIVEE, pas un chiffre invente : la regle et
-- l'image disent alors la meme chose. Le banc verifie que les deux valeurs restent egales — si
-- quelqu'un change l'animation sans changer la regle, il le saura.
--
-- Fonctions pures, verifiees hors Studio (tools/test_deploiement.py) ; le serveur applique.
local Deploiement = {}

-- Doit rester egal a Effets.APPARITION_DUREE (verifie au banc). On ne fait pas `require` ici :
-- ce module decrit une REGLE, Effets dessine — et un module de regles qui depend du rendu serait
-- inutilisable au banc.
Deploiement.DUREE = 0.45
Deploiement.DUREE_MAX = 2  -- borne de securite : au-dela, la carte semblerait ne pas repondre

-- Duree propre a une carte. Aujourd'hui la meme pour toutes : une duree par carte serait un
-- reglage d'equilibrage, pas une regle, et rien ne la justifie encore.
function Deploiement.duree(carte)
	local d = tonumber(carte and carte.deploiement) or Deploiement.DUREE
	return math.clamp(d, 0, Deploiement.DUREE_MAX)
end

-- L'unite est-elle operationnelle ? `depuis` = secondes ecoulees depuis la pose.
-- Une unite sans instant de pose connu est consideree PRETE : on ne bloque jamais une unite par
-- accident (les tours, par exemple, n'ont pas de pose).
function Deploiement.pret(depuis, duree)
	if depuis == nil then
		return true
	end
	return (tonumber(depuis) or 0) >= (duree or Deploiement.DUREE)
end

-- Temps restant avant d'etre operationnelle, borne a zero (sert a l'affichage).
function Deploiement.restant(depuis, duree)
	if depuis == nil then
		return 0
	end
	local r = (duree or Deploiement.DUREE) - (tonumber(depuis) or 0)
	if r < 0 then
		return 0
	end
	return r
end

-- ===== LE MONTRER A L'ECRAN =====
--
-- Defaut mesure le 2026-09-21 : la regle existe, elle est expliquee au manuel depuis aujourd'hui,
-- mais RIEN ne la montre en jeu. Celui qui pose ne sait pas quand son unite devient active ; celui
-- d'en face ne voit pas qu'il a encore une demi-seconde pour reagir. Un anneau au sol qui se
-- referme le dit sans un mot, et il est en geometrie (une etiquette flottante n'apparait sur
-- aucune capture d'ecran du moteur).

-- AVANCEMENT du deploiement, entre 0 (a peine posee) et 1 (operationnelle).
function Deploiement.avancement(depuis, duree)
	local d = tonumber(duree) or Deploiement.DUREE
	if d <= 0 then
		return 1
	end
	local t = tonumber(depuis) or 0
	if t <= 0 then
		return 0
	end
	return math.min(1, t / d)
end

-- DIAMETRE de l'anneau : il se REFERME sur l'unite. Il part large (on le voit tout de suite) et
-- finit au ras du corps, a l'instant ou l'unite devient active — la fin du geste EST le signal.
Deploiement.ANNEAU_LARGE = 6
Deploiement.ANNEAU_SERRE = 2.2
function Deploiement.diametreAnneau(avancement)
	local a = math.max(0, math.min(1, tonumber(avancement) or 0))
	return Deploiement.ANNEAU_LARGE + (Deploiement.ANNEAU_SERRE - Deploiement.ANNEAU_LARGE) * a
end

-- COULEUR DE L'ANNEAU : elle dit LAQUELLE des deux regles de pose est en cours.
--
-- Defaut mesure le 2026-09-21 : l'unite qui arrive est INTOUCHABLE pendant un court instant
-- (Statuts.INVULN_POSE, 0,35 s) — c'est ce qui empeche le « sort lance pile sur la pose ». La
-- regle etait appliquee et expliquee au manuel, mais rien ne la montrait : celui qui lance son
-- sort croit l'avoir rate, celui qui pose ignore qu'il est protege.
--
-- BLANC tant qu'elle est intouchable, OR ensuite : l'anneau raconte les deux temps de la pose
-- avec un seul objet, au lieu d'empiler deux effets sur la meme unite.
Deploiement.COULEUR_INTOUCHABLE = { 255, 255, 255 }
-- Orange FRANC, et non un or pale : sous l'eclairage bleu des arenes sombres, un or clair se
-- lisait comme du blanc sur la photo (capture cap-invuln.png du 2026-09-21). Les deux temps de la
-- pose doivent se distinguer sur TOUS les decors, pas seulement en plein jour.
Deploiement.COULEUR_VULNERABLE = { 255, 140, 20 }

function Deploiement.intouchable(depuis, dureeInvuln)
	return (tonumber(depuis) or 0) < (tonumber(dureeInvuln) or 0)
end

-- Aucune COQUE autour de l'unite : essayee le 2026-09-21 puis RETIREE. Trois formes ont ete
-- tentees pour montrer l'invulnerabilite (couleur de l'anneau, second disque concentrique, coque
-- spherique) et sept captures n'en ont rendu aucune lisible : les unites portent deja un halo
-- lumineux qui absorbe tout ce qu'on pose par-dessus. La regle reste appliquee par le serveur et
-- EXPLIQUEE au manuel (section LA POSE) ; on n'empile pas un effet de plus qui ne se voit pas.

function Deploiement.couleurAnneau(depuis, dureeInvuln)
	if Deploiement.intouchable(depuis, dureeInvuln) then
		return Deploiement.COULEUR_INTOUCHABLE
	end
	return Deploiement.COULEUR_VULNERABLE
end

-- Il s'efface a mesure qu'il se referme : sinon il resterait plein juste avant de disparaitre,
-- et la disparition ressemblerait a un defaut d'affichage.
function Deploiement.transparenceAnneau(avancement)
	local a = math.max(0, math.min(1, tonumber(avancement) or 0))
	return 0.15 + 0.7 * a
end

return Deploiement
