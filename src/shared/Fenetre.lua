-- FENETRE : pousser au moment ou l'adversaire ne peut PAS repondre.
--
-- Pourquoi ce module existe. Mesure du 2026-09-21, six duels de paliers, 120 parties : une fois
-- l'inversion du seuil d'attaque corrigee, les trois paliers hauts se valaient toujours —
-- aguerri 32 victoires, normal 31, expert 30, indistinguables. La raison se lit dans la table des
-- paliers : `anticipe`, `contre` et `economise` sont a `true` pour les TROIS. Seuls des reglages
-- numeriques faibles les separaient, et le principal (le temps de reflexion) ne change rien du
-- tout — mesure : les trois posent exactement le meme nombre de cartes par seconde
-- (0,356 / 0,365 / 0,369). Le jeu est limite par l'ELIXIR, pas par la vitesse de decision.
-- Rendre un robot « plus rapide » ne le rend donc pas meilleur ; il fallait une COMPETENCE.
--
-- Celle-ci : LIRE L'ELIXIR ADVERSE et pousser quand il est a sec. C'est le geste qui separe un
-- joueur qui progresse d'un joueur qui joue ses cartes des qu'il les a. Le jeu propose deja cette
-- lecture au JOUEUR (Lecture.elixirEstime, affichee en haut a gauche) ; le robot, lui, ne la
-- regardait pas.
--
-- HONNETETE DU ROBOT : il n'a pas le droit de lire le compteur reel de l'adversaire. Il part de
-- la meme ESTIMATION que le joueur — construite sur le temps ecoule et les cartes vues — puis
-- l'entache d'une erreur d'autant plus grande que son palier lit mal. Un expert estime juste, un
-- aguerri se trompe de deux elixir, un normal ne regarde pas.
--
-- Fonctions pures, verifiees hors Studio (tools/test_fenetre.py) ; le serveur applique.
local Fenetre = {}

-- Erreur maximale d'estimation, en elixir, pour un robot qui ne lit pas du tout.
Fenetre.ERREUR_MAX = 4
-- Cout de la reponse type. C'est le cout MEDIAN du catalogue (voir Reserve.MEDIANE) : si
-- l'adversaire ne peut pas payer ca, il ne peut rien opposer de serieux.
Fenetre.COUT_REPONSE = 3

-- ESTIMATION que se fait un robot de l'elixir adverse.
--   reel      : l'estimation honnete (celle que le joueur verrait), deja bornee
--   precision : 0 = aveugle, 1 = lit juste
--   tirage    : nombre entre 0 et 1 fourni par l'appelant (le serveur passe math.random())
-- L'erreur est CENTREE : le robot peut surestimer comme sous-estimer, sinon sa « mauvaise
-- lecture » serait un biais systematique dont il finirait par profiter.
function Fenetre.estimation(reel, precision, tirage)
	local base = math.clamp(tonumber(reel) or 0, 0, 10)
	local p = math.clamp(tonumber(precision) or 0, 0, 1)
	local t = math.clamp(tonumber(tirage) or 0.5, 0, 1)
	local amplitude = Fenetre.ERREUR_MAX * (1 - p)
	local erreur = (t * 2 - 1) * amplitude
	return math.clamp(base + erreur, 0, 10)
end

-- LA FENETRE EST-ELLE OUVERTE ? Vrai quand l'adversaire, d'apres ce que le robot croit, ne peut
-- pas payer une reponse. Un robot de precision nulle ne voit JAMAIS de fenetre : il ne regarde
-- pas, donc il ne doit tirer aucun avantage de ce module.
function Fenetre.ouverte(estimation, precision, cout)
	if (tonumber(precision) or 0) <= 0 then
		return false
	end
	return (tonumber(estimation) or 0) < (tonumber(cout) or Fenetre.COUT_REPONSE)
end

-- COMMENT SE SERVIR DE LA FENETRE — et la premiere version se trompait de sens.
--
-- Premier essai (2026-09-21) : fenetre ouverte -> ABAISSER le seuil d'attaque, pour engager plus
-- tot. Mesure sur 60 parties, normal contre expert : l'expert n'a gagne que **38 %**, et la cause
-- se lit dans les journaux — il posait ses cartes a **4,0 elixir de mediane contre 5,8** pour le
-- normal. Abaisser le seuil avait simplement fabrique un robot imprudent, c'est-a-dire le defaut
-- exact que la correction precedente venait d'eliminer (correlation r = +0,98 entre seuil
-- d'attaque et victoires : dans ce jeu, attaquer tot fait perdre).
--
-- Le sens utile est donc l'INVERSE : la lecture ne sert pas a se precipiter quand l'adversaire
-- est a sec, elle sert a ATTENDRE quand il peut repondre. Fenetre fermee -> le robot exige plus
-- d'elixir avant d'engager ; fenetre ouverte -> il attaque a son seuil habituel. Un robot qui lit
-- bien ne jette donc plus ses cartes dans une defense prete.
Fenetre.PATIENCE_MAX = 2 -- elixir exiges EN PLUS quand l'adversaire peut repondre

function Fenetre.patience(precision)
	local p = math.clamp(tonumber(precision) or 0, 0, 1)
	return Fenetre.PATIENCE_MAX * p
end

-- SEUIL D'ATTAQUE effectif. Inchange quand la fenetre est ouverte ; majore quand elle est fermee,
-- a proportion de ce que le robot sait lire. Borne au plafond d'elixir du jeu : au-dela, il
-- n'attaquerait jamais, et une partie sans attaque n'est pas une partie.
Fenetre.SEUIL_MAX = 10

function Fenetre.seuilEffectif(seuilBase, ouverte, precision)
	local s = tonumber(seuilBase) or 0
	if ouverte then
		return s
	end
	return math.min(Fenetre.SEUIL_MAX, s + Fenetre.patience(precision))
end

return Fenetre
