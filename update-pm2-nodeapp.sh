currdir=$(pwd)
cd /var/www/nodeapp/
pm2 stop nodeapp
git pull
pm2 start nodeapp
cd "$currdir"
