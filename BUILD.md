# Finance App - Build Instructions

## Prerequisites

- Node.js 18+ with pnpm
- Rust 1.70+ with cargo
- Tauri CLI

## Development

```bash
# Install dependencies
pnpm install

# Run development server
pnpm tauri dev
```

## Production Build

```bash
# Build for production
pnpm tauri build
```

Build artifacts will be created in:
- Executable: `src-tauri/target/release/finance-app.exe` (Windows)
- Installer: `src-tauri/target/release/bundle/msi/Finance App_0.1.0_x64_en-US.msi`

## Build Configuration

Configuration is in `src-tauri/tauri.conf.json`:
- Product Name: Finance App
- Version: 0.1.0
- Identifier: com.finance.app
- Bundle: MSI (Windows), DMG (macOS), AppImage (Linux)

## Testing

```bash
# Backend tests
cd src-tauri
cargo test

# Frontend tests
pnpm vitest run

# Type checking
pnpm type-check
```

## Verification

After building, verify the application:
1. Run the executable from `src-tauri/target/release/`
2. Test core features:
   - Create account
   - Record transaction
   - Create debt
   - View reports
   - Sync functionality

## Known Issues

- Build time: 10-15 minutes for first build
- Windows Defender may flag the executable (false positive)
- Database migrations run automatically on first launch
