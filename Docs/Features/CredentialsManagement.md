# Centralized Credentials Management

## Overview
Centralized the miner credentials (username/password) management to allow users to configure them from the UI instead of having them hardcoded in multiple places.

## Changes Made

### Backend (`backend/`)

1. **New Config Module** (`backend/src/core/config.rs`)
   - Created `MinerCredentials` struct to hold username/password
   - Provides `Default` implementation (root/root)
   - Exported from `core` module

2. **Updated Commands API** (`backend/src/api/commands.rs`)
   - `execute_batch_command()` now accepts `Option<MinerCredentials>`
   - Falls back to default (root/root) if `None` is provided
   - Removed hardcoded `DEFAULT_USERNAME` and `DEFAULT_PASSWORD` constants
   - Credentials are passed through to `reboot_via_http()`

3. **FFI Bridge Regeneration**
   - Ran `flutter_rust_bridge_codegen generate` to update bindings
   - The new `credentials` parameter is now available in Dart

### Frontend (`frontend/`)

1. **Credentials Service** (`lib/src/services/credentials_service.dart`)
   - Manages persistent storage of credentials using `shared_preferences`
   - Methods: `getUsername()`, `getPassword()`, `setUsername()`, `setPassword()`, `resetToDefaults()`
   - Defaults to root/root if not configured

2. **Settings Dialog** (`lib/src/widgets/settings_dialog.dart`)
   - User-friendly dialog for configuring credentials
   - Shows/hides password with toggle button
   - Reset to defaults button
   - Saves to persistent storage

3. **Main App** (`lib/main.dart`)
   - Added settings button (⚙️) to AppBar
   - Opens `SettingsDialog` when clicked

4. **Miner List View** (`lib/src/widgets/miner_list_view.dart`)
   - Updated to fetch credentials from `CredentialsService`
   - Uses configured credentials when opening miner web pages (long-press)

5. **Dependencies** (`pubspec.yaml`)
   - Added `shared_preferences: ^2.3.3` for persistent storage

## How It Works

### For Users
1. Click the **Settings** button (⚙️) in the top-right corner
2. Enter custom username/password (or keep defaults: root/root)
3. Click **Save**
4. Credentials are now used for:
   - Opening miner web pages (long-press on a row)
   - Sending reboot commands via HTTP Digest Auth

### For Developers
```dart
// Frontend: Get credentials
final username = await CredentialsService.getUsername();
final password = await CredentialsService.getPassword();

// Pass to backend (optional - defaults to root/root if None)
final creds = MinerCredentials(username: username, password: password);
await executeBatchCommand(ips, MinerCommand.reboot, creds);
```

```rust
// Backend: Use credentials
pub async fn execute_batch_command(
    target_ips: Vec<String>,
    command: MinerCommand,
    credentials: Option<MinerCredentials>, // Optional - defaults to root/root
) -> Vec<CommandResult>
```

## Future Enhancements
- Per-miner credentials (some miners may have different passwords)
- Credential validation/testing before saving
- Encrypted storage for passwords
- Import/export settings
