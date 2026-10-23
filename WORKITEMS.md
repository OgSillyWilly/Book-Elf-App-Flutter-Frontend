# Work items: add authentication to the Flutter app

Backend context: every endpoint except `POST /api/register` and `POST /api/login` now requires `Authorization: Bearer <token>` and returns 401 JSON otherwise. Other users' records return 404. Tokens expire after 30 days. See `HANDOFF.md` in the backend repo (`Book-Elf-App-Laravel-Backend`).

The app has no users yet, so breaking changes are fine. Suggested order: FE-1 → FE-2 → FE-3 → FE-4 → FE-5 → FE-6.

**Progress rule:** When a work item is completed, update its heading to `[x]` and add a brief completion note describing the changes and verification.

## [x] FE-1 Token storage and AuthService
- Add `flutter_secure_storage` (not `shared_preferences`) to store the token.
- Create `lib/services/auth_service.dart` with `register`, `login`, `logout`, `currentUser` and `token`. Register it in [service_locator.dart](lib/service_locator.dart).
- Endpoints (base URL from `AppConfig.apiBaseUrl`):
  - `POST /register` with `name, email, password, password_confirmation` returns 201 `{user, token, token_type}`.
  - `POST /login` with `email, password` returns 200 with the same shape. Wrong credentials return 422.
  - `POST /logout` revokes the token.
  - `GET /user` returns the current user.
- Rate limit: register and login allow 10 requests per minute and return 429. Show a friendly message.
- Done when: a token survives an app restart and logout clears it.
- Completed: added secure token storage, auth endpoints, 401 token clearing, and friendly 429/422 errors; registered `AuthService` in the service locator. Verified with `flutter analyze` and `git diff --check`.

## [x] FE-2 Authenticated HTTP layer
- About 33 raw `http` calls, mostly in `services/implementations/api_data_service.dart`, plus `services/image_upload_service.dart`, `google_books_service.dart`, `books_list_screen.dart` and `widgets/book_grid_item.dart`.
- Introduce one authenticated client (an `http.BaseClient` wrapper, or a helper that adds the `Authorization` and `Accept: application/json` headers) and route all backend calls through it.
- `image_upload_service.dart` uses `MultipartRequest`, so it needs the header set on the request.
- Do not send the backend token to third parties: `google_books_service.dart` must stay on a plain client.
- On a 401 response: clear the token and navigate to login (a global handler, not per call).
- Done when: no direct `http.get/post/put/delete` calls to the backend remain.
- Completed: added `AuthenticatedClient` (registered in the service locator); `ApiDataService` (incl. import) and `ImageUploadService` (multipart and delete) now use it; `GoogleBooksService` stays on a plain client. A 401 clears the token (only if it is still the rejected one) and `AuthService.sessionExpired` fires; `main.dart` listens globally, returns to the root route and shows a snackbar. Verified with 5 new unit tests (`test/authenticated_client_test.dart`) and a search showing no raw backend `http.*` calls left.
- Follow-ups: `getTemplateUrl()` still shows a plain URL to open in a browser, which will now 401 (the template download needs an authenticated fetch).

## [x] FE-3 Login and register screens plus auth gate
- Add `login_screen.dart` and `register_screen.dart`, with validation and server-side 422 errors shown per field.
- Update [splash_screen.dart](lib/screens/splash_screen.dart) and `main.dart`: if there is a token, call `GET /user`, then go to the book list; otherwise go to login.
- Add a logout button in [settings_screen.dart](lib/screens/settings_screen.dart), plus a display of the current user.
- Completed: added `login_screen.dart` and `register_screen.dart` (local validation, 422 errors per field, friendly 429/connection messages). The splash resolves the session (token → `GET /user`; a 401 goes to login, offline keeps the session) and `main.dart` swaps splash/login/book list. Logout and expired sessions (401) both return to login via `AuthService.loggedOut` / `sessionExpired`; the book list is rebuilt on re-login. Settings has a new `AccountCard` showing the user and a logout button. Verified with 4 new widget tests (`test/login_screen_test.dart`) plus the existing client tests; `flutter analyze` shows no new errors. Not run against the deployed API or on a device.
- Follow-up: logout does not yet evict cached cover images (FE-4).

## [x] FE-4 Authenticated cover images
- `cover_url` values returned by the API are `/api/image-proxy?url=...` (needs the token) or `/storage/covers/{user_id}/...` (public).
- Update [widgets/cover_image.dart](lib/widgets/cover_image.dart): pass `httpHeaders: {'Authorization': 'Bearer ...'}` to `Image.network` (web) and `CachedNetworkImage` (mobile) for image-proxy URLs.
- Also update the direct `Image.network` usages: `statistics_screen.dart`, `enhanced_statistics_screen.dart`, `book_detail_screen.dart` and `reading_challenge_screen.dart` (2 places). Switch them to the shared `CoverImage` widget.
- Note: the `CachedNetworkImage` cache key is the URL, so evict images on logout so the next user doesn't see cached covers.
- Done when: covers render when logged in and no image-proxy request goes out without a header.
- Completed: `CoverImage` now normalizes the URL and, for backend `/image-proxy` URLs only (`isAuthenticatedImageUrl` in `url_utils.dart`), passes the bearer token (`headers:` on `Image.network`, `httpHeaders:` on `CachedNetworkImage`); without a token it shows the placeholder instead of requesting. Third-party covers (e.g. Google Books) never get the token. All direct `Image.network` usages (`statistics_screen`, `enhanced_statistics_screen`, `book_detail_screen`, `reading_challenge_screen` x2) now use `CoverImage`. Logout and 401 clear the Flutter image cache and the `DefaultCacheManager` disk cache (`utils/image_cache_utils.dart`, called from `main.dart`); `flutter_cache_manager` added as a direct dependency. Verified with 6 new tests (`test/cover_image_test.dart`) and `flutter analyze` (no new errors). Not checked against the deployed API; on web the proxy needs CORS to allow the `Authorization` header.

## [x] FE-5 API contract changes
- Other users' records return 404, so treat 404 on a detail screen as "not found".
- `series_id` is now accepted and validated on book create and update (it was silently ignored before). Send it from [book_form_screen.dart](lib/screens/book_form_screen.dart) and handle the 422 on `series_id`.
- Cover URLs are now `/storage/covers/{user_id}/...`. Don't assume the old path format.
- Delete or hide the unused `api_service.dart.backup` and `local_data_service.dart` paths, or make sure they don't call the backend unauthenticated.
- Completed: `NotFoundException`/`ValidationException` (`lib/services/api_exceptions.dart`); 404 on book, series and challenge detail is "not found" (book detail pops with a message, the others show their "niet gevonden" state). `Book` has `seriesId`; the book form has a "Serie" selector (loaded from `getSeries()`, existing `series_id` is preserved if the list fails to load) and sends `series_id`; a 422 on `series_id` shows on the field, other 422s in a dialog. `updateBook` no longer hides 404/422 behind the CORS-debug message. Cover URLs are rendered through `CoverImage`, so the `/storage/covers/{user_id}/` format needs no code change. Deleted `api_service.dart.backup` and the unused `local_data_service.dart` (this also removed the old analyzer error). Verified with `flutter analyze` (no errors) and `test/api_contract_test.dart` (9 tests); not run against the deployed API.
- Follow-up: `series_order` is still not accepted by the backend request rules, so it is not sent.

## FE-6 Tests and verification
- Unit-test `AuthService` and the authenticated client (header added, 401 handling).
- Manual check against the deployed API with two accounts: each sees only its own books, series, challenges and statistics, and logging out and in as the other user shows no stale cached data.
- Update the README with the login flow.
- Status: all but the manual check are done; the heading stays unchecked until the two-account check has been run.
- Completed so far: `test/auth_service_test.dart` (13 tests: login/register token storage and persistence across instances, 422 field errors, 429 message, missing token, logout success/failure/no token, `currentUser`, 401 clearing + `sessionExpired`, stale-token 401 ignored); the authenticated client was already covered in `test/authenticated_client_test.dart`. README has a new "Inloggen (authenticatie)" section. 37 tests pass; `flutter analyze` has no errors.
- Still to do (needs a person): the two-account check against the deployed API, including that logging out and in as the other user shows no stale cached covers or data.
