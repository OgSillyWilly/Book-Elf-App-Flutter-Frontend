#!/bin/bash

echo "🔍 Book Elf - Server Diagnostics"
echo "=================================="
echo ""

# Check if Laravel server is running
echo "1️⃣ Controleren of Laravel server draait..."
if lsof -i :8000 2>/dev/null | grep -q LISTEN; then
    echo "   ✅ Server draait op poort 8000"
    lsof -i :8000 | grep LISTEN | awk '{print "   Process: " $1 " (PID: " $2 ")"}'
else
    echo "   ❌ Geen server gevonden op poort 8000"
    echo ""
    echo "   Start de server met:"
    echo "   cd /Users/silkedelvaux/Herd/Book-Elf-App-Laravel-Backend"
    echo "   ./start-server.sh"
    echo ""
    exit 1
fi

echo ""

# Test API connection
echo "2️⃣ Testen API verbinding..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/api/books 2>/dev/null)

if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ API bereikbaar (HTTP $HTTP_CODE)"
    
    # Count books
    BOOK_COUNT=$(curl -s http://127.0.0.1:8000/api/books 2>/dev/null | grep -o '"id"' | wc -l | xargs)
    echo "   📚 Aantal boeken in database: $BOOK_COUNT"
else
    echo "   ❌ API niet bereikbaar (HTTP $HTTP_CODE)"
    echo ""
    echo "   Mogelijke oorzaken:"
    echo "   - Server is bezig met opstarten (wacht 5 sec en probeer opnieuw)"
    echo "   - Database verbinding problemen"
    echo "   - Routes niet correct geladen"
    echo ""
fi

echo ""

# Check network interfaces
echo "3️⃣ Actieve netwerk interfaces:"
IP_ADDRESSES=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print "   " $2}')
if [ -z "$IP_ADDRESSES" ]; then
    echo "   ⚠️  Geen externe IP gevonden"
else
    echo "$IP_ADDRESSES"
fi

echo ""

# Test from external IP (if applicable)
EXTERNAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
if [ ! -z "$EXTERNAL_IP" ]; then
    echo "4️⃣ Testen vanaf extern IP ($EXTERNAL_IP)..."
    HTTP_CODE_EXT=$(curl -s -o /dev/null -w "%{http_code}" http://$EXTERNAL_IP:8000/api/books --connect-timeout 3 2>/dev/null)
    
    if [ "$HTTP_CODE_EXT" = "200" ]; then
        echo "   ✅ API bereikbaar vanaf extern IP"
    else
        echo "   ⚠️  API niet bereikbaar vanaf extern IP (normaal voor localhost)"
        echo "   Gebruik http://127.0.0.1:8000/api in de Flutter app als je op dezelfde machine test"
    fi
fi

echo ""
echo "=================================="
echo "💡 Tips:"
echo "   - Voor lokale testing: gebruik 127.0.0.1:8000"
echo "   - Voor iPhone via USB: gebruik je Mac IP adres"
echo "   - Controleer baseUrl in lib/config/app_config.dart"
echo ""
