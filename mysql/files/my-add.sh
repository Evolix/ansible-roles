!/bin/sh

echo "Ajout d'un compte/base MySQL"
echo "Entrez le nom de la nouvelle base MySQL"
read base

echo "Entrez le login qui aura tous les droits sur cette base"
echo "(Vous pouvez entrer un login existant)"
read login

echo -n "Cet utilisateur est-il deja existant ? [y|N] "
read confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
echo "Attention, si l'utilisateur etait existant, il sera ecrase !"
echo -n "Entrez le mot de passe MySQL (ou vide pour aleatoire) :"
read -s passe2
echo ""

length=${#passe2}

if [ -n $passe ]; then
    passe2=$(apg -n1 -E FollyonWek7)
    echo "Mot de passe genere : $passe2"
fi

mysql << END_SCRIPT
    CREATE DATABASE \`$base\`;
    GRANT ALL PRIVILEGES ON \`$base\`.* TO \`$login\`@localhost IDENTIFIED BY "$passe2";
    FLUSH PRIVILEGES;
END_SCRIPT

else

mysql << END_SCRIPT
    CREATE DATABASE \`$base\`;
    GRANT ALL PRIVILEGES ON \`$base\`.* TO \`$login\`@localhost;
    FLUSH PRIVILEGES;
END_SCRIPT

fi

echo "Si aucune erreur, creation de la base MySQL $base OK"
