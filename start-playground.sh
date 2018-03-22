#!/bin/bash

echo "www.pdbmbook.com -- Principles of Database Management"
echo "-----------------------------------------------------"
echo "Going to start up the playground environment now"
echo "Once loaded (a message will appear), you can open"
echo "a Web Browser and go to the Home Page"
echo ""

read -p "Press ENTER to start..."

echo ""
echo ""

docker stop $(docker ps -a -q)
docker rm $(docker ps -a -q)

docker run -i -t -p 8081:80 5f5fd5b355b3