# 📚 Boekenkast App

Flutter app voor het beheren van je boekencollectie.

## 🚀 Quick Start

### Makkelijkste manier (keuzemenu):
```bash
./quick-start.sh
```

### Of direct starten:

**Chrome (web):**
```bash
./start-chrome.sh
```
De app opent op: http://localhost:8080

**iPhone:**
```bash
./start-iphone.sh
```

## ⚡ Development Tips

### Hot Reload (tijdens het runnen)
- `r` - Hot reload (snelle refresh zonder state te verliezen)
- `R` - Hot restart (volledige restart van de app)
- `q` - Stop de app

### Backend Server
Zorg dat de Laravel backend draait:
```bash
cd ../Book-Elf-App-Laravel-Backend
php artisan serve --host=0.0.0.0 --port=8000
```

## 🛠️ Handmatige Start

### Alle beschikbare devices zien:
```bash
flutter devices
```

### Op specifiek device runnen:
```bash
flutter run -d chrome          # Chrome browser
flutter run -d iphone          # iPhone via USB
flutter run -d <device-id>     # Specifiek device
```

### Met custom port (web):
```bash
flutter run -d chrome --web-port=8080
```

## 📱 iPhone Setup

1. **USB Verbinding:**
   - Sluit iPhone aan via USB
   - Trust de computer op je iPhone (popup verschijnt eerste keer)
   - Voer wachtwoord in op iPhone om te bevestigen

2. **Development Profile:**
   - Open iOS Settings > General > VPN & Device Management
   - Trust je development certificate (Apple Development)
   - Bevestig met je iPhone wachtwoord

3. **Draadloos Debuggen (optioneel, werkt niet altijd):**
   
   **Voorwaarden:**
   - iPhone en Mac op **hetzelfde WiFi netwerk**
   - iPhone minstens 1x via USB verbonden geweest
   - Xcode geïnstalleerd (voor Devices window)
   
   **Stappen als Xcode beschikbaar is:**
   - Open Xcode
   - Menu: Window > Devices and Simulators (of ⇧⌘2)
   - Selecteer je iPhone in de linker lijst
   - Zoek naar "Connect via network" checkbox (rechterkant)
   - Indien zichtbaar: vink aan → USB kan weg
   
   **Let op:** Deze optie is niet altijd beschikbaar:
   - Sommige iOS/Xcode versies ondersteunen het niet
   - WiFi moet stabiel zijn
   - Eerste keer altijd USB nodig
   
   **Alternatief (zonder Xcode):**
   Je kunt gewoon via USB blijven werken - hot reload werkt prima!
   - USB is eigenlijk sneller en stabieler
   - Geen WiFi problemen
   - Makkelijkste optie voor development

## 🌐 Chrome Development

### Voordelen:
- Snelle development cycle
- DevTools beschikbaar (F12)
- Makkelijk testen van UI changes

### Features testen:
- Text selectie werkt nu!
- Dark mode toggle
- Responsive design
- Alle CRUD operaties

## 🔧 Troubleshooting

### "No devices found"
```bash
flutter doctor -v  # Check Flutter setup
flutter devices    # Zie beschikbare devices
```

### iPhone niet zichtbaar
1. Disconnect en reconnect USB
2. Trust computer op iPhone
3. Herstart Flutter: `flutter clean && flutter pub get`

### Chrome port al in gebruik
Stop het oude proces of gebruik andere port:
```bash
flutter run -d chrome --web-port=8081
```

### Build errors
```bash
flutter clean
flutter pub get
flutter run
```

## 📦 API Configuratie

### Automatische Configuratie
De app kiest automatisch het juiste API endpoint:
- **Chrome/Web:** `http://127.0.0.1:8000/api` (localhost)
- **iPhone/Android:** `http://10.242.187.102:8000/api` (netwerk IP)

### Custom API URL Instellen
Als je netwerk IP verandert of een andere server wilt gebruiken:

1. Open de app
2. Ga naar ⋮ menu → **Instellingen**
3. Voer custom API URL in
4. Klik **Test Verbinding** om te controleren
5. Klik **Opslaan**
6. **Herstart de app**

### Troubleshooting - TimeoutException

**Symptoom:** `Exception: Verbinding timeout`

**Oplossing:**
```bash
# 1. Check of server draait
cd bookshelf_app
./check-server.sh

# 2. Test API handmatig
curl http://127.0.0.1:8000/api/books

# 3. Als server niet draait
cd ../Book-Elf-App-Laravel-Backend
./start-server.sh
```

**In de app:**
- Open Instellingen (⋮ menu)
- Test verbinding
- Zie welk IP adres je moet gebruiken
- Pas aan indien nodig

### IP Adres Vinden
```bash
# macOS / Linux
ifconfig | grep "inet " | grep -v 127.0.0.1

# Gebruik het eerste IP (bijv. 10.242.187.102)
```

## 🔐 Inloggen (authenticatie)

De API gebruikt Laravel Sanctum tokens. Alle data (boeken, series, challenges, statistieken, covers) is per gebruiker; alleen `register` en `login` zijn publiek.

- **Flow:** bij het opstarten controleert de splash screen het opgeslagen token via `GET /user`. Geldig → boekenlijst, anders → loginscherm (met link naar registreren). Offline blijft een opgeslagen sessie behouden.
- **Token:** opgeslagen met `flutter_secure_storage` (Keychain/Keystore), beheerd door `AuthService` (`lib/services/auth_service.dart`).
- **Requests:** alle backend-calls lopen via `AuthenticatedClient` en krijgen `Authorization: Bearer <token>` + `Accept: application/json`. Google Books gebruikt een gewone client (het token gaat nooit naar derden).
- **Covers:** `CoverImage` stuurt het token alleen mee voor `/image-proxy` URLs van de eigen backend.
- **401:** het token wordt gewist, de cache van afbeeldingen geleegd en de app gaat terug naar het loginscherm.
- **Uitloggen:** Instellingen → account-kaart → Uitloggen. Dit wist het token en de afbeeldingscache.
- **Rate limit:** login/registreren staat 10 pogingen per minuut toe (429 → vriendelijke melding).
- **Web:** de API-CORS-instellingen moeten de `Authorization` header toestaan.

Tests draaien met `flutter test` (let op: `test/widget_test.dart` is de standaard counter-template en faalt nog).

## ✨ Features

- ✅ Boeken toevoegen/bewerken/verwijderen
- ✅ Google Books API integratie (auto-fill)
- ✅ Bulk selectie en verwijderen
- ✅ Excel/CSV import
- ✅ Dark mode
- ✅ Filteren op status/genre
- ✅ Zoeken op titel/auteur
- ✅ Book covers met CORS proxy
- ✅ Selecteerbare tekst (web)

## 🎨 Thema's

- **Light mode:** Warm brown/beige Material Design 3
- **Dark mode:** Deep blue met high contrast
- Toggle via 🌙 icon in app bar

