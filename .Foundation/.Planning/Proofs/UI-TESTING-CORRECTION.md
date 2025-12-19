# Swift Testing UI Testing Correction

## Issue Identified

The user correctly pointed out that Swift Testing **does NOT** support UI testing with XCUITest. The original documentation was misleading about Swift Testing's capabilities.

## Official Documentation Evidence

From `.planning/swiftDocs/Testing/SwiftTests/Meet_swift_testing.md` (line 372):

> "Please continue using XCTest for any tests which use UI automation APIs like XCUIApplication or use performance testing APIs like XCTMetric as these are not supported in Swift Testing."

## Corrections Made

### 1. Updated Framework Usage Guidelines

**Before:**
```
## Testing Framework: Swift Testing (Primary) + XCTest (Legacy/UI)

**Default to Swift Testing** for all new unit tests. Use XCTest only for:
- UI testing (XCUITest)
- Performance testing
- Legacy test compatibility
```

**After:**
```
## Testing Framework: Swift Testing (Primary) + XCTest (UI/Performance)

**Default to Swift Testing** for all new unit tests. Use XCTest ONLY for:
- **UI testing** with XCUIApplication (XCUITest)
- **Performance testing** with XCTMetric
- **Objective-C** compatibility
- **Legacy test** compatibility during migration
```

### 2. Added Important Limitations Section

```
### Important Limitations

**Swift Testing does NOT support:**
- UI automation APIs like `XCUIApplication`
- Performance testing APIs like `XCTMetric`
- Objective-C code (Swift-only framework)
- Mixed assertion usage (don't call XCTest assertions from Swift Testing tests)
```

### 3. Updated Migration Strategy

**Before:**
```
3. **UI tests**: Keep using XCTest (XCUITest)
4. **Performance tests**: Keep using XCTest
```

**After:**
```
3. **UI tests**: Keep using XCTest (XCUITest) - **Swift Testing doesn't support UI automation**
4. **Performance tests**: Keep using XCTest (XCTMetric) - **Swift Testing doesn't support performance testing**
5. **Objective-C tests**: Keep using XCTest - **Swift Testing is Swift-only**
```

### 4. Enhanced DON'T List

Added important restrictions:
```
❌ Mix XCTest and Swift Testing assertions
❌ Use Swift Testing for UI automation (use XCTest)
❌ Use Swift Testing for performance testing (use XCTest)
```

### 5. Added Swift Testing Limitations Section

```
### Swift Testing Limitations
- **UI Testing**: Use XCTest with XCUIApplication (Swift Testing doesn't support UI automation)
- **Performance Testing**: Use XCTest with XCTMetric (Swift Testing doesn't support performance testing)
- **Objective-C**: Swift Testing is Swift-only (use XCTest for Objective-C tests)
- **Mixed Assertions**: Don't mix XCTest and Swift Testing assertions in same test
```

## Key Takeaways

1. **Swift Testing is for unit tests only** - it does NOT support UI automation
2. **XCTest remains essential** for UI testing with XCUIApplication
3. **Performance testing** must still use XCTest with XCTMetric
4. **Objective-C compatibility** requires XCTest (Swift Testing is Swift-only)
5. **Mixed usage** is possible but assertions should not be mixed

## Impact

This correction ensures developers understand the clear boundaries between the two testing frameworks:

- **Swift Testing**: Modern unit testing with better syntax, parallel execution, parameterized tests
- **XCTest**: Required for UI automation, performance testing, and Objective-C compatibility

The documentation now accurately reflects Apple's official guidance on when to use each framework.

---

**Date**: October 26, 2025  
**Correction Source**: Official Apple documentation in swiftDocs  
**File Updated**: `.planning/Proofs/cursorrules-template-swift.md`

