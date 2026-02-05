# TodoGlass

TodoGlass is an iOS SwiftUI app that stores your todos as GitHub Issues. It uses OAuth to sign in, lets you pick a repository, and gives you three tabs: **My Todos**, **All Issues**, and **Add**.

## Features
- OAuth sign-in with GitHub
- Pick a repo after login
- My Todos = issues assigned to you
- All Issues = all issues in the selected repo
- Add new issues
- Edit issue details: title, description, assignees, labels, milestone, state
- Due dates stored in the issue body as `Due: YYYY-MM-DD`
- Relationships: blocked by, parent/child
- Auto-save on edits

## Requirements
- macOS with Xcode installed
- iOS 17+ target
- XcodeGen (for project generation)

## Setup

### 1) Create a GitHub OAuth App
- Go to GitHub **Settings → Developer settings → OAuth Apps**
- Create a new OAuth App with:
  - **Homepage URL**: any valid URL (e.g., your GitHub profile)
  - **Authorization callback URL**: `todoglass://oauth/callback`

### 2) Configure the app
Update the values in `TodoGlass/Sources/AppConfig.swift`:
- `githubClientId`
- `githubClientSecret` (required for token exchange)

### 3) Generate the Xcode project
```bash
brew install xcodegen
xcodegen
```

### 4) Run in Simulator
```bash
xcodebuild -scheme TodoGlass -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' -derivedDataPath build
APP_PATH=$(ls -d build/Build/Products/Debug-iphonesimulator/*.app | head -n1)
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.chrisnewsome.todoglass
```

Or open the project in Xcode:
```bash
open TodoGlass.xcodeproj
```

## Notes
- GitHub Issues do not have native due dates. This app stores due dates in the issue body.
- Relationship APIs (blocked by, parent/child) may depend on GitHub account features and repo settings.
- If OAuth scopes change, sign out and sign in again.

## Project Structure
```
TodoGlass/
  Sources/
    Auth/
    Models/
    Networking/
    UI/
    Utilities/
  Resources/
```

## Security
This app currently stores the GitHub OAuth client secret in the app bundle for simplicity. For production, use a backend token exchange to avoid embedding secrets in the client.
