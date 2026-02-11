# FlowState Production Readiness Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix all production readiness issues identified in the SSO/codebase audit so FlowState is ready for App Store submission.

**Architecture:** Fixes are organized into independent task groups that can run in parallel. Each group touches distinct files with no overlap. The work is purely bug fixes, hardening, and polish - no new features.

**Tech Stack:** SwiftUI, SwiftData, Swift Testing, Cloudflare Workers (JS)

---

### Task 1: Fix iOS Deployment Target

**Files:**
- Modify: `FlowSate.xcodeproj/project.pbxproj` (lines 325, 383, 473, 495)

**Step 1: Fix deployment target**

Replace all instances of `IPHONEOS_DEPLOYMENT_TARGET = 26.2` with `IPHONEOS_DEPLOYMENT_TARGET = 18.0` in the pbxproj file. There are 4 occurrences.

**Step 2: Commit**

```bash
git add FlowSate.xcodeproj/project.pbxproj
git commit -m "fix: set iOS deployment target to 18.0"
```

---

### Task 2: Centralize Mood Emoji Logic

The `moodEmoji(for:)` switch is duplicated in 6+ files. Centralize it as an extension on `String`.

**Files:**
- Modify: `FlowSate/Item.swift` - Already has `moodEmoji` computed property, good.
- Modify: `FlowSate/HomeView.swift` - Remove `moodEmoji(for:)` from TodayEntryCard and EntryRowCard, use `entry.moodEmoji` instead
- Modify: `FlowSate/WeeklyOverviewView.swift` - Remove `moodEmoji(for:)`, use helper
- Modify: `FlowSate/WeeklyReviewView.swift` - Remove `moodEmoji(for:)`, use helper
- Modify: `FlowSate/ExportManager.swift` - Remove `moodEmoji(for:)`, use helper
- Modify: `FlowSate/Views/Components/MoodSuggestionBanner.swift` - Remove `moodEmoji(for:)`, use helper

**Step 1: Add standalone `moodEmoji(for:)` function to Item.swift**

Add a module-level helper function at the bottom of `Item.swift`:

```swift
func moodEmoji(for mood: String) -> String {
    switch mood.lowercased() {
    case "happy": return "😊"
    case "calm": return "😌"
    case "sad": return "😔"
    case "frustrated": return "😤"
    case "thoughtful": return "🤔"
    default: return "😐"
    }
}
```

**Step 2: Remove duplicate `moodEmoji(for:)` methods**

In each of these files, delete the private `moodEmoji(for:)` method and replace call sites with the centralized function:

- `HomeView.swift` (TodayEntryCard lines 288-297, EntryRowCard lines 378-387) - Delete both private methods. Call sites already use `moodEmoji(for:)` function name, so they'll bind to the new module-level function.
- `WeeklyOverviewView.swift` (lines 220-229) - Delete private method.
- `WeeklyReviewView.swift` (lines 32-41) - Delete private method.
- `ExportManager.swift` (lines 39-48) - Delete `private static func moodEmoji`. Change call sites from `Self.moodEmoji(for:)` to `moodEmoji(for:)`.
- `MoodSuggestionBanner.swift` (lines 18-27) - Delete private method.

**Step 3: Commit**

```bash
git add FlowSate/Item.swift FlowSate/HomeView.swift FlowSate/WeeklyOverviewView.swift FlowSate/WeeklyReviewView.swift FlowSate/ExportManager.swift FlowSate/Views/Components/MoodSuggestionBanner.swift
git commit -m "refactor: centralize moodEmoji function, remove 6 duplicates"
```

---

### Task 3: Fix Word Count to Use Proper Word Boundaries

**Files:**
- Modify: `FlowSate/Item.swift` (lines 29, 46-48)

**Step 1: Fix word count in init and updateWordCount**

Replace the naive `content.split(separator: " ").count` with proper word enumeration:

In `init`: change line 29 from:
```swift
self.wordCount = content.split(separator: " ").count
```
to:
```swift
self.wordCount = content.wordCount
```

Replace `updateWordCount()` (lines 46-48) with:
```swift
func updateWordCount() {
    wordCount = content.wordCount
}
```

Add a private extension at the bottom of the file:
```swift
extension String {
    var wordCount: Int {
        var count = 0
        enumerateSubstrings(in: startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in
            count += 1
        }
        return count
    }
}
```

**Step 2: Update tests for new word count behavior**

The existing tests should still pass because `String.enumerateSubstrings(byWords:)` handles multiple spaces and leading/trailing spaces correctly. Verify by building tests.

**Step 3: Commit**

```bash
git add FlowSate/Item.swift
git commit -m "fix: use proper word boundary detection for word count"
```

---

### Task 4: Add Delete Confirmation to Entry Library

**Files:**
- Modify: `FlowSate/EntryLibraryView.swift` (lines 57-59, plus new state)

**Step 1: Add confirmation dialog**

Add state variables to `EntryLibraryView`:
```swift
@State private var entryToDelete: JournalEntry?
@State private var showingDeleteConfirmation = false
```

Change the `.onDelete` handler (lines 57-59) to store the entry instead of deleting immediately:
```swift
.onDelete { indexSet in
    if let index = indexSet.first {
        entryToDelete = section.entries[index]
        showingDeleteConfirmation = true
    }
}
```

Add a `.confirmationDialog` to the `Group` after `.sheet(isPresented: $showingExportSheet)`:
```swift
.confirmationDialog(
    "Delete Entry?",
    isPresented: $showingDeleteConfirmation,
    presenting: entryToDelete
) { entry in
    Button("Delete", role: .destructive) {
        modelContext.delete(entry)
    }
} message: { entry in
    Text("This will permanently delete your entry from \(entry.formattedDate). This cannot be undone.")
}
```

**Step 2: Commit**

```bash
git add FlowSate/EntryLibraryView.swift
git commit -m "feat: add confirmation dialog before deleting journal entries"
```

---

### Task 5: Guard AI Features Behind Auth Check

**Files:**
- Modify: `FlowSate/HomeView.swift` (lines 78, 97, 149)

**Step 1: Replace `AIService.shared.isEnabled` checks with `canUseAI`**

`AIService.shared.canUseAI` already exists and checks both `isEnabled` AND `authState.isSignedIn`. Replace 3 locations:

Line 78: `if AIService.shared.isEnabled && AIService.shared.smartPromptsEnabled {`
→ `if AIService.shared.canUseAI && AIService.shared.smartPromptsEnabled {`

Line 97: `if AIService.shared.isEnabled && entries.count >= 14 {`
→ `if AIService.shared.canUseAI && entries.count >= 14 {`

Line 149: `if AIService.shared.isEnabled && AIService.shared.chatEnabled {`
→ `if AIService.shared.canUseAI && AIService.shared.chatEnabled {`

Also in `WeeklyReviewView.swift` line 154:
`if AIService.shared.isEnabled && AIService.shared.themeDetectionEnabled {`
→ `if AIService.shared.canUseAI && AIService.shared.themeDetectionEnabled {`

**Step 2: Commit**

```bash
git add FlowSate/HomeView.swift FlowSate/WeeklyReviewView.swift
git commit -m "fix: guard AI features behind auth check, not just isEnabled"
```

---

### Task 6: Fix CloudflareClient Token Expiry Check + Retry on 401

**Files:**
- Modify: `FlowSate/Services/CloudflareClient.swift` (lines 188-189, 87-92, 146-151)

**Step 1: Check token expiry before sending**

Replace `authorizationToken()` (line 188-189):
```swift
private func authorizationToken() -> String? {
    AuthenticationManager.shared.currentToken
}
```

This uses `AuthenticationManager.currentToken` which already checks expiry.

**Step 2: Commit**

```bash
git add FlowSate/Services/CloudflareClient.swift
git commit -m "fix: check token expiry before API calls in CloudflareClient"
```

---

### Task 7: Fix Token Refresh → Sign Out on Failure

**Files:**
- Modify: `FlowSate/Services/AuthenticationManager.swift` (lines 163-198)

**Step 1: Sign out when refresh fails with 401**

In `refreshTokenIfNeeded()`, change the guard after checking httpResponse:

Replace (around line 188):
```swift
guard let httpResponse = response as? HTTPURLResponse,
      httpResponse.statusCode == 200 else { return false }
```

With:
```swift
guard let httpResponse = response as? HTTPURLResponse else { return false }
if httpResponse.statusCode == 401 {
    signOut()
    return false
}
guard httpResponse.statusCode == 200 else { return false }
```

**Step 2: Commit**

```bash
git add FlowSate/Services/AuthenticationManager.swift
git commit -m "fix: sign out when token refresh returns 401"
```

---

### Task 8: Improve Chat Error Messages

**Files:**
- Modify: `FlowSate/Views/JournalChatView.swift` (lines 207-211)

**Step 1: Show specific error messages based on error type**

Replace the error handling block (lines 207-211):
```swift
} catch {
    if let index = messages.firstIndex(where: { $0.id == assistantID }),
       messages[index].content.isEmpty {
        messages[index].content = "Sorry, I couldn't process that. Please try again."
    }
}
```

With:
```swift
} catch {
    if let index = messages.firstIndex(where: { $0.id == assistantID }),
       messages[index].content.isEmpty {
        let errorMessage: String
        if let apiError = error as? ClaudeAPIError {
            switch apiError {
            case .unauthorized:
                errorMessage = "Your session has expired. Please sign in again in Settings."
            case .rateLimited:
                errorMessage = "Too many messages sent. Please wait a moment and try again."
            case .noWorkerURL:
                errorMessage = "AI is not configured. Set up your Worker URL in Settings > AI Features."
            case .overloaded:
                errorMessage = "The AI service is busy right now. Please try again shortly."
            default:
                errorMessage = "Something went wrong. Please try again."
            }
        } else {
            errorMessage = "Connection error. Check your internet and try again."
        }
        messages[index].content = errorMessage
    }
}
```

**Step 2: Commit**

```bash
git add FlowSate/Views/JournalChatView.swift
git commit -m "fix: show specific error messages in journal chat"
```

---

### Task 9: Remove Unused authorizationCode from Worker

**Files:**
- Modify: `FlowSate/Services/AuthenticationManager.swift` - Remove `authCode` from request
- Modify: `FlowSate/Models/AuthModels.swift` - Remove field from struct

**Step 1: Remove authorizationCode from AppleAuthRequest**

In `AuthModels.swift`, remove the `authorizationCode` field from `AppleAuthRequest`:

```swift
nonisolated struct AppleAuthRequest: Codable, Sendable {
    let identityToken: String
    let userIdentifier: String
    let email: String?
    let fullName: String?
}
```

**Step 2: Remove authCode construction in AuthenticationManager**

In `AuthenticationManager.swift`, remove line 72:
```swift
let authCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
```

And remove `authorizationCode: authCode,` from the `AppleAuthRequest` constructor (line 79).

**Step 3: Commit**

```bash
git add FlowSate/Services/AuthenticationManager.swift FlowSate/Models/AuthModels.swift
git commit -m "chore: remove unused authorizationCode from auth request"
```

---

### Task 10: Fix Force-Unwrap in FlowSateApp ModelContainer

**Files:**
- Modify: `FlowSate/FlowSateApp.swift` (line 39)

**Step 1: Replace try! with fatalError with a message**

Replace (line 37-39):
```swift
let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
return try! ModelContainer(for: schema, configurations: [memoryConfig])
```

With:
```swift
do {
    let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [memoryConfig])
} catch {
    fatalError("FlowState could not create any data store: \(error.localizedDescription)")
}
```

This still crashes (as it should - can't run without a data store) but provides a clear diagnostic.

**Step 2: Commit**

```bash
git add FlowSate/FlowSateApp.swift
git commit -m "fix: replace try! with fatalError with diagnostic message"
```

---

### Task 11: Add Nonce Validation to Cloudflare Worker

**Files:**
- Modify: `cloudflare-worker/worker.js`

**Step 1: Add nonce generation endpoint**

Add a new route before the existing routes in the fetch handler (after line 98):

```javascript
if (url.pathname === "/auth/nonce" && request.method === "POST") {
    return handleNonceGeneration(request, env);
}
```

Add the handler function:

```javascript
async function handleNonceGeneration(request, env) {
    const clientIP = request.headers.get("CF-Connecting-IP") || "unknown";
    if (isAuthRateLimited(clientIP, 10)) {
        return jsonResponse({ error: "Rate limited" }, 429, { "Retry-After": "60" });
    }

    const nonceBytes = crypto.getRandomValues(new Uint8Array(32));
    const nonce = base64UrlEncode(String.fromCharCode(...nonceBytes));
    const expiresAt = Date.now() + 5 * 60 * 1000; // 5 minutes

    // Store nonce in KV or use HMAC-based validation
    // Since Workers don't have persistent state without KV, use HMAC approach:
    // Sign the nonce with the secret so we can verify it later without storage
    const hmacKey = await crypto.subtle.importKey(
        "raw",
        new TextEncoder().encode(env.JWT_SECRET),
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["sign"]
    );
    const payload = `${nonce}:${expiresAt}`;
    const sig = await crypto.subtle.sign("HMAC", hmacKey, new TextEncoder().encode(payload));
    const signature = base64UrlEncode(String.fromCharCode(...new Uint8Array(sig)));

    return jsonResponse({ nonce, expiresAt, signature });
}
```

**Step 2: Validate nonce in handleAppleAuth**

In `handleAppleAuth`, after extracting `identityToken` and `userIdentifier`, also extract and validate the nonce:

After line 133 (`const { identityToken, userIdentifier } = body;`), add:

```javascript
const { nonce: clientNonce, nonceSignature, nonceExpiresAt } = body;

// Validate nonce if provided (backwards compatible)
if (clientNonce && nonceSignature && nonceExpiresAt) {
    if (Date.now() > nonceExpiresAt) {
        return jsonResponse({ error: "Nonce expired" }, 400);
    }

    const hmacKey = await crypto.subtle.importKey(
        "raw",
        new TextEncoder().encode(env.JWT_SECRET),
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["verify"]
    );
    const expectedPayload = `${clientNonce}:${nonceExpiresAt}`;
    const expectedSig = base64UrlDecode(nonceSignature);
    const nonceValid = await crypto.subtle.verify(
        "HMAC", hmacKey, expectedSig, new TextEncoder().encode(expectedPayload)
    );
    if (!nonceValid) {
        return jsonResponse({ error: "Invalid nonce" }, 400);
    }

    // Verify the Apple token contains the expected nonce
    if (applePayload.nonce !== clientNonce) {
        return jsonResponse({ error: "Nonce mismatch" }, 401);
    }
}
```

Move the nonce validation to after `verifyAppleToken` since we need `applePayload`. The final order should be:
1. Extract body fields
2. Verify Apple token
3. Validate nonce against Apple token
4. Verify subject match
5. Issue JWT

**Step 3: Update iOS client to request and use nonce**

In `AuthenticationManager.swift`, add a nonce request before sign-in:

Add a new method:
```swift
private func fetchNonce() async throws -> (nonce: String, signature: String, expiresAt: Int) {
    let workerURL = CloudflareClient.workerURL
    guard !workerURL.isEmpty else { throw AuthError.serverValidationFailed("Worker URL not configured") }

    let urlString = workerURL.hasSuffix("/") ? workerURL + "auth/nonce" : workerURL + "/auth/nonce"
    guard let url = URL(string: urlString) else { throw AuthError.serverValidationFailed("Invalid URL") }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("alnotha.FlowSate", forHTTPHeaderField: "X-App-Bundle")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        throw AuthError.serverValidationFailed("Failed to get nonce")
    }

    struct NonceResponse: Codable {
        let nonce: String
        let expiresAt: Int
        let signature: String
    }

    let nonceResponse = try JSONDecoder().decode(NonceResponse.self, from: data)
    return (nonceResponse.nonce, nonceResponse.signature, nonceResponse.expiresAt)
}
```

Update `handleAppleSignIn` to include the nonce in the request. Also update `AppleAuthRequest` to include optional nonce fields:

In `AuthModels.swift`, add to `AppleAuthRequest`:
```swift
let nonce: String?
let nonceSignature: String?
let nonceExpiresAt: Int?
```

The sign-in flow in the view needs to set nonce on the ASAuthorizationAppleIDRequest. This requires the view to fetch the nonce first and pass it. Update `AISettingsView.swift` to coordinate this.

**Note:** This is the most complex task. The nonce must be:
1. Fetched from the worker before presenting the Sign in with Apple sheet
2. SHA256-hashed and set as `request.nonce` on the `ASAuthorizationAppleIDRequest`
3. Sent (unhashed) to the worker alongside the identity token
4. The worker verifies Apple's token contains the SHA256 of the nonce

Update `AISettingsView.swift` to use a manual ASAuthorizationController approach instead of `SignInWithAppleButton` so we can set the nonce. Actually, `SignInWithAppleButton` does support nonce via the request closure. We just need to hash it:

```swift
import CryptoKit

SignInWithAppleButton(.signIn) { request in
    request.requestedScopes = [.email, .fullName]
    if let nonce = self.currentNonce {
        request.nonce = SHA256.hash(data: Data(nonce.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
```

Store the raw nonce in state so it can be sent to the worker.

**Step 4: Remove the TODO comment**

Delete lines 5-7 from `worker.js`.

**Step 5: Commit**

```bash
git add cloudflare-worker/worker.js FlowSate/Services/AuthenticationManager.swift FlowSate/Models/AuthModels.swift FlowSate/Views/AISettingsView.swift
git commit -m "feat: add nonce validation for Sign in with Apple replay protection"
```

---

### Task 12: Set AccentColor

**Files:**
- Modify: `FlowSate/Assets.xcassets/AccentColor.colorset/Contents.json`

**Step 1: Set accent color to blue (matching app's primary action color)**

Replace contents with:
```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "1.000",
          "green" : "0.478",
          "red" : "0.000"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

This is iOS system blue (#007AFF) which matches the existing `.blue` usage throughout the app.

**Step 2: Commit**

```bash
git add FlowSate/Assets.xcassets/AccentColor.colorset/Contents.json
git commit -m "feat: set AccentColor to system blue"
```

---

### Task 13: Prevent Saving Empty Entries

**Files:**
- Modify: `FlowSate/HomeView.swift` (line 221-225 - createTodayEntry)

**Context:** Currently `createTodayEntry()` creates and immediately inserts a blank entry. The entry exists even if the user dismisses without writing. This is actually fine because the editor auto-focuses and the entry is usable. BUT we should clean up truly empty entries on dismiss.

**Step 1: Delete empty entry on editor dismiss**

In `HomeView.swift`, update the `.sheet` modifier (lines 173-179) to clean up on dismiss:

```swift
.sheet(isPresented: $showingEditor, onDismiss: {
    if let entry = todayEntry, entry.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        modelContext.delete(entry)
    }
}) {
    if let entry = todayEntry {
        NavigationStack {
            JournalEditorView(entry: entry)
        }
    }
}
```

**Step 2: Commit**

```bash
git add FlowSate/HomeView.swift
git commit -m "fix: delete empty entries when editor is dismissed without writing"
```

---

### Task 14: Build and Test

**Step 1: Build the project**

```bash
xcodebuild -project FlowSate.xcodeproj -scheme FlowSate \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

Expected: BUILD SUCCEEDED

**Step 2: Run tests**

```bash
xcodebuild -project FlowSate.xcodeproj -scheme FlowSate \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

Expected: All existing tests pass.

**Step 3: Final commit if any fixes needed**

Fix any compilation or test issues discovered during build.

---

## Task Dependency Graph

Tasks 1-13 are independent and can run in parallel (they touch different files), EXCEPT:

- Task 2 (mood emoji centralization) and Task 5 (guard AI behind auth) both modify `HomeView.swift` - **run sequentially**
- Task 2 and Task 5 both touch `WeeklyReviewView.swift` - **run sequentially**
- Task 9 (remove authCode) and Task 11 (add nonce) both modify `AuthModels.swift` and `AuthenticationManager.swift` - **run sequentially, do Task 9 first**
- Task 11 (nonce) and Task 8 (chat errors) are independent

**Suggested parallel groups:**

| Group A | Group B | Group C | Group D |
|---------|---------|---------|---------|
| Task 1 (deployment target) | Task 3 (word count) | Task 4 (delete confirm) | Task 8 (chat errors) |
| Task 2 (mood centralize) | Task 6 (token expiry) | Task 12 (accent color) | Task 10 (force unwrap) |
| Task 5 (AI auth guard) | Task 7 (refresh signout) | Task 13 (empty entries) | |
| | Task 9 (remove authCode) | | |
| | Task 11 (nonce validation) | | |

Task 14 (build + test) runs last after all groups complete.
