# Dependency Injection with GetIt

## Overview

The app now uses dependency injection with GetIt to manage services. This allows easy switching between:
- **API Mode**: Connect to Laravel backend (network required)
- **Local Mode**: Use SQLite database (offline) - *Coming soon*

## Architecture

```
lib/
  service_locator.dart              # GetIt configuration
  services/
    interfaces/
      i_data_service.dart           # Single interface for all data operations
    implementations/
      api_data_service.dart         # Laravel API implementation
    google_books_service.dart       # External service
    image_upload_service.dart       # Utility service
```

## Usage

### New Way (Recommended)

```dart
import 'package:get_it/get_it.dart';
import '../service_locator.dart';
import '../services/interfaces/i_data_service.dart';

class MyScreen extends StatefulWidget {
  // ...
}

class _MyScreenState extends State<MyScreen> {
  late final IDataService _dataService;
  
  @override
  void initState() {
    super.initState();
    _dataService = getIt<IDataService>();
  }
  
  Future<void> _loadBooks() async {
    final books = await _dataService.getBooks();
    // ...
  }
}
```

## Switching Between API and Local Mode

```dart
import 'service_locator.dart';

// Switch to local mode
await switchServiceMode(ServiceMode.local);

// Switch to API mode
await switchServiceMode(ServiceMode.api);

// Check current mode
final currentMode = await getCurrentServiceMode();
```

## Migration Guide

### Step 1: Update Screen Initialization

**Before:**
```dart
final ApiService _apiService = ApiService();
```

**After:**
```dart
late final IDataService _dataService;

@override
void initState() {
  super.initState();
  _dataService = getIt<IDataService>();
}
```

### Step 2: Update Service Calls

**Before:**
```dart
final books = await _apiService.getBooks();
```

**After:**
```dart
final books = await _dataService.getBooks();
```

### Step 3: Add Imports

```dart
import '../service_locator.dart';
import '../services/interfaces/i_data_service.dart';
```

## Benefits

✅ **Easy to test**: Mock IDataService for unit tests  
✅ **Flexible**: Switch data source without changing screens  
✅ **Clean**: Single interface for all data operations  
✅ **Future-proof**: Ready for SQLite implementation  

## Next Steps

1. Gradually migrate screens to use GetIt
2. Implement LocalDataService with SQLite
3. Add settings toggle to switch modes

## Status

- ✅ GetIt configured
- ✅ IDataService interface created
- ✅ ApiDataService implemented
- ✅ ApiService compatibility alias removed
- ⏳ LocalDataService not implemented
- ⏳ Screen migration (0/11 screens)
- ⏳ SQLite implementation
- ⏳ Settings UI for mode switching
