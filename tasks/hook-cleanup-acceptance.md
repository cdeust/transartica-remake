# Essai du nettoyage après push

Cet essai vérifie le retrait automatique du worktree et de sa branche locale après un push vers une PR existante. Il ne modifie pas le jeu.

Le worktree appartient à la session Codex qui réalise le test. La PR distante et les preuves conservées sont enregistrées avant le push mesuré. Après ce push, les seules commandes de l’agent sont des contrôles en lecture seule : aucun appel au nettoyage, aucune suppression manuelle.

La réussite exige que le chemin du worktree et sa branche locale aient disparu, tandis que le commit reste disponible dans la PR GitHub. Leur présence après le push constitue un échec.

PR de test : https://github.com/cdeust/transartica-remake/pull/1

État : ce commit constitue le push mesuré. Le résultat sera vérifié depuis le checkout principal après le retour du push.
