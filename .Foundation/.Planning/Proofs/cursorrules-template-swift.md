# Foundation Framework - Cursor Rules for Swift Development

This file should be saved as `.cursorrules` in your Swift project root.

---

## Core Principle: Test-Driven Generation

**NEVER write code without simultaneously writing and running tests.**

---

## Testing Framework: Swift Testing (Primary) + XCTest (UI/Performance)

**Default to Swift Testing** for all new unit tests. Use XCTest ONLY for:
- **UI testing** with XCUIApplication (XCUITest)
- **Performance testing** with XCTMetric
- **Objective-C** compatibility
- **Legacy test** compatibility during migration

---

## Mandatory Protocol for ALL Swift Code

### 1. WRITE CODE + TESTS TOGETHER

For EVERY function, component, or feature you implement:

```swift
// ❌ WRONG: Code only
func login(username: String, password: String) -> Bool {
    // implementation
}

// ✅ CORRECT: Code + Swift Testing Tests in same response
import Testing

@Test("Login with valid credentials")
func loginValidCredentials() {
    let result = login(username: "user@example.com", password: "SecurePass123")
    #expect(result == true)
}

@Test("Login with invalid credentials")
func loginInvalidCredentials() {
    let result = login(username: "user@example.com", password: "wrong")
    #expect(result == false)
}

@Test("Login with empty fields")
func loginEmptyFields() {
    let result = login(username: "", password: "")
    #expect(result == false)
}
```

### 2. RUN TESTS IMMEDIATELY

After writing code + tests:
- Execute `swift test`
- Check compilation
- Verify all tests PASS
- Do NOT proceed until passing

### 3. DEBUG CODE AND TESTS IN PARALLEL

If tests fail:
- Analyze BOTH code and test
- Fix whichever is wrong (or both)
- Re-run tests
- Max 3 attempts before requesting human help

### 4. ACCESSIBLE-FIRST CODE DESIGN IS MANDATORY

**Design code with accessibility built-in from the start, not added later.**

#### UI Elements MUST Include Accessibility Properties

```swift
// ✅ CORRECT: Accessibility built into the design
Button("Login") {
    performLogin()
}
.accessibilityIdentifier("login_submit_button")
.accessibilityLabel("Login")
.accessibilityHint("Tap to log in with your credentials")
.accessibilityAddTraits(.isButton)

// ❌ WRONG: Accessibility added as afterthought
Button("Login") {
    performLogin()
}
// Missing accessibility properties
```

#### Accessibility Requirements for ALL UI Elements

**Text Elements:**
```swift
Text("Welcome")
    .accessibilityLabel("Welcome message")
    .accessibilityAddTraits(.isStaticText)
```

**Text Fields:**
```swift
TextField("Username", text: $username)
    .accessibilityIdentifier("username_field")
    .accessibilityLabel("Username")
    .accessibilityHint("Enter your username")
```

**Images:**
```swift
Image("logo")
    .accessibilityLabel("Company logo")
    .accessibilityHint("Decorative image")
```

**Custom Views:**
```swift
CustomView()
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Combined description of contents")
```

#### Accessibility Testing Requirements

Every UI element MUST be testable via accessibility identifiers:
```swift
// In UI tests
let loginButton = app.buttons["login_submit_button"]
XCTAssertTrue(loginButton.exists)
XCTAssertEqual(loginButton.label, "Login")
```

### 5. VERIFY BEFORE PROCEEDING

Complete this checklist for every feature:
- [ ] Implementation code written with accessibility built-in
- [ ] Swift Testing unit tests written
- [ ] UI tests written (if applicable)
- [ ] All UI elements have accessibility identifiers
- [ ] All UI elements have accessibility labels
- [ ] All interactive elements have accessibility hints
- [ ] All elements have appropriate accessibility traits
- [ ] Tests compiled successfully
- [ ] Tests executed successfully
- [ ] ALL tests PASSED
- [ ] Code documented
- [ ] Accessibility verified with VoiceOver/assistive technologies

---

## Accessibility-First Design Principles

### Core Accessibility Requirements

**Every UI element MUST be designed with accessibility from the start:**

1. **Unique Identifiers**: Every interactive element needs a unique `accessibilityIdentifier`
2. **Clear Labels**: Every element needs a descriptive `accessibilityLabel`
3. **Helpful Hints**: Interactive elements need `accessibilityHint` explaining the action
4. **Appropriate Traits**: Elements need correct `accessibilityAddTraits`
5. **Logical Order**: Elements must follow logical reading order
6. **Sufficient Contrast**: Text must meet WCAG contrast requirements
7. **Touch Targets**: Interactive elements must be at least 44x44 points

### Accessibility Implementation Patterns

#### Button Accessibility
```swift
// ✅ Complete button accessibility
Button("Save Changes") {
    saveChanges()
}
.accessibilityIdentifier("save_changes_button")
.accessibilityLabel("Save Changes")
.accessibilityHint("Tap to save your changes")
.accessibilityAddTraits(.isButton)

// ❌ Incomplete accessibility
Button("Save") {
    saveChanges()
}
// Missing accessibility properties
```

#### Form Field Accessibility
```swift
// ✅ Complete form field accessibility
VStack {
    Text("Email Address")
        .accessibilityLabel("Email Address")
    
    TextField("Enter email", text: $email)
        .textFieldStyle(.roundedBorder)
        .keyboardType(.emailAddress)
        .textInputAutocapitalization(.never)
        .accessibilityIdentifier("email_field")
        .accessibilityLabel("Email Address")
        .accessibilityHint("Enter your email address")
        .accessibilityAddTraits(.isKeyboardKey)
    
    if !email.isEmpty && !isValidEmail(email) {
        Text("Please enter a valid email address")
            .foregroundColor(.red)
            .accessibilityIdentifier("email_error_message")
            .accessibilityLabel("Error: Please enter a valid email address")
            .accessibilityAddTraits(.isStaticText)
    }
}
```

#### Navigation Accessibility
```swift
// ✅ Accessible navigation
NavigationView {
    List(items) { item in
        NavigationLink(destination: ItemDetailView(item: item)) {
            ItemRowView(item: item)
        }
        .accessibilityIdentifier("item_\(item.id)")
        .accessibilityLabel("\(item.name), \(item.description)")
        .accessibilityHint("Tap to view details")
        .accessibilityAddTraits(.isButton)
    }
    .accessibilityLabel("Items list")
}
```

#### Custom Component Accessibility
```swift
// ✅ Accessible custom component
struct RatingView: View {
    let rating: Int
    let maxRating: Int = 5
    
    var body: some View {
        HStack {
            ForEach(1...maxRating, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .foregroundColor(index <= rating ? .yellow : .gray)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rating: \(rating) out of \(maxRating) stars")
        .accessibilityAddTraits(.isStaticText)
    }
}
```

### Accessibility Testing Integration

#### Unit Tests for Accessibility Logic
```swift
@Test("Email validation accessibility")
func emailValidationAccessibility() {
    let validator = EmailValidator()
    
    // Test valid email
    let validResult = validator.validate("user@example.com")
    #expect(validResult.isValid == true)
    #expect(validResult.accessibilityMessage == "Valid email address")
    
    // Test invalid email
    let invalidResult = validator.validate("invalid")
    #expect(invalidResult.isValid == false)
    #expect(invalidResult.accessibilityMessage == "Please enter a valid email address")
}
```

#### UI Tests for Accessibility
```swift
func testAccessibility_loginForm_allElementsAccessible() {
    // Test that all elements are discoverable
    let emailField = app.textFields["email_field"]
    let passwordField = app.secureTextFields["password_field"]
    let loginButton = app.buttons["login_submit_button"]
    
    XCTAssertTrue(emailField.exists)
    XCTAssertTrue(passwordField.exists)
    XCTAssertTrue(loginButton.exists)
    
    // Test accessibility labels
    XCTAssertEqual(emailField.label, "Email Address")
    XCTAssertEqual(passwordField.label, "Password")
    XCTAssertEqual(loginButton.label, "Login")
    
    // Test accessibility hints
    XCTAssertEqual(emailField.hint, "Enter your email address")
    XCTAssertEqual(passwordField.hint, "Enter your password")
    XCTAssertEqual(loginButton.hint, "Tap to log in")
    
    // Test accessibility traits
    XCTAssertTrue(emailField.hasKeyboardFocus)
    XCTAssertTrue(loginButton.isButton)
}
```

### Accessibility Best Practices

#### DO:
✅ Design accessibility into every UI element from the start  
✅ Use semantic HTML elements and SwiftUI components  
✅ Provide clear, concise accessibility labels  
✅ Include helpful hints for interactive elements  
✅ Use appropriate accessibility traits  
✅ Test with VoiceOver and other assistive technologies  
✅ Ensure sufficient color contrast (4.5:1 minimum)  
✅ Make touch targets at least 44x44 points  
✅ Follow logical reading order  
✅ Provide alternative text for images  
✅ Use heading structure for content hierarchy  

#### DON'T:
❌ Add accessibility as an afterthought  
❌ Use generic or unclear accessibility labels  
❌ Forget accessibility hints for interactive elements  
❌ Use color alone to convey information  
❌ Make touch targets too small  
❌ Skip accessibility testing  
❌ Use decorative images without proper labeling  
❌ Create confusing navigation patterns  
❌ Ignore VoiceOver testing  
❌ Use low contrast colors  

### Accessibility Testing Checklist

For every UI component:
- [ ] Has unique `accessibilityIdentifier`
- [ ] Has descriptive `accessibilityLabel`
- [ ] Has helpful `accessibilityHint` (if interactive)
- [ ] Has appropriate `accessibilityAddTraits`
- [ ] Is discoverable in UI tests
- [ ] Works with VoiceOver
- [ ] Has sufficient color contrast
- [ ] Has adequate touch target size
- [ ] Follows logical reading order
- [ ] Provides meaningful feedback
- [ ] Handles error states accessibly
- [ ] Supports keyboard navigation (if applicable)

---

## Swift Testing Requirements

### Core Concepts

Swift Testing uses four building blocks:
1. **Test Functions**: Marked with `@Test` attribute
2. **Expectations**: `#expect` and `#require` macros
3. **Traits**: Customize test behavior
4. **Suites**: Organize related tests

### Test Function Declaration

```swift
import Testing

// Basic test function
@Test func videoMetadata() {
    let video = Video(fileName: "By the Lake.mov")
    #expect(video.metadata != nil)
}

// Test with display name
@Test("Check video metadata is loaded correctly")
func videoMetadata() {
    let video = Video(fileName: "By the Lake.mov")
    #expect(video.metadata != nil)
}

// Async test
@Test func asyncOperation() async throws {
    let result = try await performAsyncOperation()
    #expect(result != nil)
}

// Test with traits
@Test(.enabled(if: AppFeatures.isEnabled))
func conditionalFeature() {
    // Test code
}
```

### Expectations: #expect vs #require

```swift
// Use #expect for regular checks (test continues on failure)
@Test func userValidation() {
    let user = User(name: "John", email: "john@example.com")
    #expect(user.name == "John")
    #expect(user.email == "john@example.com")
    #expect(user.isValid == true)
}

// Use #require for critical checks (test stops on failure)
@Test func userProcessing() throws {
    let user = User(name: "John", email: "john@example.com")
    let processedUser = try #require(processUser(user))  // Stops if nil
    #expect(processedUser.id != nil)
}

// #require for unwrapping optionals
@Test func videoLibrary() async throws {
    let videoLibrary = try await VideoLibrary()
    let video = try #require(await videoLibrary.video(named: "By the Lake"))
    #expect(video.duration > 0)
}
```

### Error Testing with #expect(throws:)

```swift
// Test that code throws any error
@Test func brewingError() throws {
    let teaLeaves = TeaLeaves(name: "EarlGrey", optimalBrewTime: 4)
    #expect(throws: (any Error).self) {
        try teaLeaves.brew(forMinutes: 200)
    }
}

// Test for specific error type
@Test func specificBrewingError() throws {
    let teaLeaves = TeaLeaves(name: "EarlGrey", optimalBrewTime: 4)
    #expect(throws: BrewingError.oversteeped) {
        try teaLeaves.brew(forMinutes: 200)
    }
}

// Custom error validation
@Test func complexErrorValidation() throws {
    let teaLeaves = TeaLeaves(name: "EarlGrey", optimalBrewTime: 4)
    #expect(throws: BrewingError.self) { error in
        try teaLeaves.brew(forMinutes: 3)
        if case .needsMoreTime(let optimalBrewTime) = error {
            return optimalBrewTime == 4
        }
        return false
    }
}
```

### Test Organization with Suites

```swift
import Testing

// Basic suite (struct recommended for value semantics)
struct VideoTests {
    let video = Video(fileName: "By the Lake.mov")
    
    @Test("Check video metadata")
    func videoMetadata() {
        let expectedMetadata = Metadata(duration: .seconds(90))
        #expect(video.metadata == expectedMetadata)
    }
    
    @Test func rating() {
        #expect(video.contentRating == "G")
    }
}

// Nested suites for better organization
@Suite("User Management Tests")
struct UserManagementTests {
    
    @Suite("User Creation")
    struct UserCreationTests {
        @Test func withValidData() {
            let user = User(name: "John", email: "john@example.com")
            #expect(user != nil)
        }
        
        @Test func withInvalidEmail() {
            let user = User(name: "John", email: "invalid")
            #expect(user == nil)
        }
    }
    
    @Suite("User Validation")
    struct UserValidationTests {
        @Test func emailValidation() { }
        @Test func passwordValidation() { }
    }
}

// Suite with init/deinit for setup/teardown
struct DatabaseTests {
    let database: Database
    
    init() async throws {
        // Setup before each test
        database = try await Database.connect()
    }
    
    @Test func insertRecord() async throws {
        try await database.insert(record: testRecord)
        #expect(await database.count() == 1)
    }
    
    @Test func queryRecords() async throws {
        let results = try await database.query()
        #expect(results.isEmpty == false)
    }
}
```

### Parameterized Testing

```swift
// Single parameter
@Test("Process video names", arguments: [
    "A Beach",
    "By the Lake",
    "Camping in the Woods",
    "The Rolling Hills"
])
func processVideoName(_ videoName: String) async throws {
    let videoLibrary = try await VideoLibrary()
    let video = try #require(await videoLibrary.video(named: videoName))
    #expect(!video.mentionedContinents.isEmpty)
    #expect(video.mentionedContinents.count <= 3)
}

// Multiple parameters (tests all combinations)
@Test(arguments: Ingredient.allCases, Dish.allCases)
func cook(_ ingredient: Ingredient, into dish: Dish) async throws {
    #expect(ingredient.isFresh)
    let result = try cook(ingredient)
    #expect(result.isDelicious)
    #expect(result == dish)
}

// Using zip() to pair arguments
@Test(arguments: zip(Ingredient.allCases, Dish.allCases))
func cookPaired(_ ingredient: Ingredient, into dish: Dish) async throws {
    #expect(ingredient.isFresh)
    let result = try cook(ingredient)
    #expect(result == dish)
}

// Parameterized with custom types
enum IceCreamFlavor: CaseIterable {
    case vanilla, chocolate, strawberry, mintChip, rockyRoad, pistachio
}

@Test(arguments: [IceCreamFlavor.vanilla, .chocolate, .strawberry, .mintChip])
func doesNotContainNuts(flavor: IceCreamFlavor) throws {
    try #require(!flavor.containsNuts)
}
```

### Test Traits

```swift
// Display name
@Test("Custom display name for test")
func myTest() { }

// Conditional execution
@Test(.enabled(if: AppFeatures.isCommentingEnabled))
func videoCommenting() { }

@Test(.disabled("Due to known crash"))
func crashingTest() { }

// OS version requirements (use @available, not #available)
@Test
@available(macOS 15, *)
func usesNewAPIs() { }

// Bug tracking
@Test(.bug("https://example.org/bugs/1234", "Program crashes at <symbol>"))
func knownBugTest() { }

// Time limits
@Test(.timeLimit(.seconds(10)))
func slowOperation() async throws {
    let result = try await performSlowOperation()
    #expect(result != nil)
}

// Tags for organization
extension Tag {
    @Tag static var unit: Self
    @Tag static var integration: Self
    @Tag static var formatting: Self
    @Tag static var critical: Self
}

@Test(.tags(.unit, .critical))
func criticalUnitTest() { }

@Suite(.tags(.integration))
struct IntegrationTests {
    @Test func apiTest() { }
    @Test func databaseTest() { }
}

// Serialized execution (run tests one at a time)
@Suite(.serialized)
struct SerialTests {
    @Test func firstTest() { }
    @Test func secondTest() { }
}
```

### Known Issues

```swift
// Mark code with known issues
@Test func softServeIceCreamInCone() throws {
    withKnownIssue {
        try softServeMachine.makeSoftServe(in: .cone)
    }
}

// Intermittent issues
@Test func flakeyTest() throws {
    withKnownIssue(isIntermittent: true) {
        try unreliableOperation()
    }
}

// Conditional known issues
@Test func conditionalIssue() throws {
    withKnownIssue(when: { isRunningOnCI }) {
        try operationThatFailsOnCI()
    }
}

// Match specific issues
@Test func specificIssue() throws {
    withKnownIssue(matching: { issue in
        issue.description.contains("specific error")
    }) {
        try problematicOperation()
    }
}
```

### Async Testing and Confirmations

```swift
// Simple async test
@Test func asyncOperation() async throws {
    let result = try await performAsync()
    #expect(result != nil)
}

// Confirmations for callbacks (replacement for XCTestExpectation)
@Test func bakeCookies() async throws {
    let cookies = await Cookie.bake(count: 10)
    try await confirmation("Ate cookies", expectedCount: 10) { ateCookie in
        try await eat(cookies, with: .milk) { cookie, crumbs in
            #expect(!crumbs.in(.milk))
            ateCookie()  // Confirm each time callback is called
        }
    }
}

// Confirmation with range (at least N times)
@Test func multipleCallbacks() async throws {
    try await confirmation("Called", expectedCount: 5...) { called in
        performOperationWithCallback { result in
            #expect(result.isValid)
            called()
        }
    }
}

// Confirmation that should never occur
@Test func neverCalled() async throws {
    try await confirmation("Should not be called", expectedCount: 0) { called in
        performOperation { result in
            called()  // This will fail the test if called
        }
    }
}
```

### Custom Test Descriptions

```swift
// For better parameterized test output
struct SoftServe: CustomTestStringConvertible {
    let flavor: Flavor
    let container: Container
    let toppings: [Topping]
    
    var testDescription: String {
        "\(flavor) in a \(container)"
    }
}

@Test(arguments: [
    SoftServe(flavor: .vanilla, container: .cone, toppings: [.sprinkles]),
    SoftServe(flavor: .chocolate, container: .cone, toppings: [.sprinkles]),
    SoftServe(flavor: .pineapple, container: .cup, toppings: [.whippedCream])
])
func softServeFlavors(_ softServe: SoftServe) {
    #expect(softServe.flavor != nil)
}
```

### Naming Conventions

```swift
// Swift Testing naming (no "test" prefix required)
@Test func userCreation() { }
@Test func userValidation() { }
@Test func userDeletion() { }

// Descriptive names with underscores for clarity
@Test func userCreation_withValidData_succeeds() { }
@Test func userCreation_withInvalidEmail_fails() { }
@Test func userCreation_withEmptyName_throwsError() { }

// Or use display names
@Test("User creation with valid data succeeds")
func userCreationSuccess() { }
```

---

## XCTest (UI/Performance Testing Only)

### When to Use XCTest

Use XCTest ONLY for:
1. **UI Testing** with XCUIApplication (XCUITest) - **NOT supported in Swift Testing**
2. **Performance Testing** with XCTMetric - **NOT supported in Swift Testing**
3. **Objective-C** compatibility - **Swift Testing is Swift-only**
4. **Legacy test compatibility** when migrating incrementally

### Important Limitations

**Swift Testing does NOT support:**
- UI automation APIs like `XCUIApplication`
- Performance testing APIs like `XCTMetric`
- Objective-C code (Swift-only framework)
- Mixed assertion usage (don't call XCTest assertions from Swift Testing tests)

### XCTest Unit Test Pattern (Legacy)

```swift
import XCTest
@testable import MyApp

class UserTests: XCTestCase {
    var userManager: UserManager!
    
    override func setUp() {
        super.setUp()
        userManager = UserManager()
    }
    
    override func tearDown() {
        userManager = nil
        super.tearDown()
    }
    
    func test_userCreation_withValidData_succeeds() {
        // Given
        let name = "John"
        let email = "john@example.com"
        
        // When
        let user = userManager.createUser(name: name, email: email)
        
        // Then
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.name, name)
        XCTAssertEqual(user?.email, email)
    }
}
```

### UI Tests with XCTest

```swift
import XCTest

class LoginUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testUI_loginView_submitButtonDisabled_whenFieldsEmpty() {
        let usernameField = app.textFields["login_username_field"]
        let passwordField = app.secureTextFields["login_password_field"]
        let loginButton = app.buttons["login_submit_button"]
        
        XCTAssertTrue(usernameField.exists)
        XCTAssertTrue(passwordField.exists)
        XCTAssertFalse(loginButton.isEnabled)
    }
    
    func testUI_loginView_submitButtonEnabled_whenFieldsFilled() {
        let usernameField = app.textFields["login_username_field"]
        usernameField.tap()
        usernameField.typeText("testuser")
        
        let passwordField = app.secureTextFields["login_password_field"]
        passwordField.tap()
        passwordField.typeText("password123")
        
        let loginButton = app.buttons["login_submit_button"]
        XCTAssertTrue(loginButton.isEnabled)
    }
    
    func testAccessibility_loginView_allElementsLabeled() {
        let usernameField = app.textFields["login_username_field"]
        XCTAssertTrue(usernameField.exists)
        XCTAssertEqual(usernameField.label, "Username")
        
        let passwordField = app.secureTextFields["login_password_field"]
        XCTAssertTrue(passwordField.exists)
        XCTAssertEqual(passwordField.label, "Password")
        
        let loginButton = app.buttons["login_submit_button"]
        XCTAssertTrue(loginButton.exists)
        XCTAssertEqual(loginButton.label, "Login")
    }
}
```

### Performance Tests with XCTest

```swift
import XCTest

class PerformanceTests: XCTestCase {
    func testPerformance_dataProcessing() {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            // Code to measure
            let data = generateLargeDataSet()
            let processed = processData(data)
            XCTAssertNotNil(processed)
        }
    }
}
```

---

## Code Generation Dialogue Pattern

Follow this exact pattern when generating code:

```
AI: "I'm implementing [Feature Name]."

AI: "Implementation code:"
[Swift code block with accessibility]

AI: "Swift Testing unit tests:"
[Swift Testing test code block covering all cases]

AI: "UI/Accessibility tests (XCTest):"
[XCUITest code block if applicable]

AI: "Running tests..."
[Execute: swift test]

AI: "Results: [Status]"

IF FAIL:
  AI: "Debugging [specific failure]..."
  AI: "Issue: [description]"
  AI: "Fix: [code change]"
  AI: "Re-running tests..."
  [Repeat until pass or max attempts]

IF PASS:
  AI: "✓ All tests passing. Feature complete."
  AI: "Moving to next component..."
```

---

## Debug Loop Protocol

When tests fail (max 3 attempts):

**Attempt 1:**
1. Analyze error message
2. Identify if code or test is wrong
3. State hypothesis clearly
4. Apply targeted fix
5. Re-run tests

**Attempt 2:**
1. Review both code AND test logic
2. Check assumptions
3. Apply more comprehensive fix
4. Re-run tests

**Attempt 3:**
1. Deep analysis of failure
2. Consider alternative approaches
3. Apply final fix attempt
4. Re-run tests

**If still failing:**
Signal for human intervention with:
- What was attempted
- Why it's failing
- What's unclear
- Specific help needed

---

## Accessibility Standards

### Text Elements
```swift
Text("Hello")
    .accessibilityLabel("Greeting message: Hello")
```

### Buttons
```swift
Button("Submit") {
    action()
}
.accessibilityIdentifier("submit_button")
.accessibilityLabel("Submit")
.accessibilityHint("Tap to submit the form")
```

### Text Fields
```swift
TextField("Username", text: $username)
    .accessibilityIdentifier("username_field")
    .accessibilityLabel("Username")
```

### Images
```swift
Image("logo")
    .accessibilityLabel("Company logo")
    .accessibilityHint("Decorative image")
```

### Custom Views
```swift
CustomView()
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Combined description of contents")
```

---

## Code Quality Standards

All code must:
- Follow Swift naming conventions (camelCase, descriptive names)
- Include comments for non-obvious logic
- Handle errors with proper do-catch or Result types
- Use guard statements for early returns
- Avoid force unwrapping (no `!` unless justified in comment)
- Keep functions focused (single responsibility)
- Use meaningful variable names (no single letters except in closures)

---

## Performance Guidelines

- Mock network calls in tests
- Use test doubles for expensive operations
- Keep test execution under 1 second per test
- Run only affected tests when possible
- Use `@MainActor` appropriately for UI code
- Avoid blocking main thread

---

## Documentation Requirements

Every feature must include:

```swift
/// Brief description of what this function does
///
/// - Parameters:
///   - param1: Description of param1
///   - param2: Description of param2
/// - Returns: Description of return value
/// - Throws: Description of possible errors
func exampleFunction(param1: String, param2: Int) throws -> Bool {
    // Implementation
}
```

---

## Parallel Testing and Concurrency

### Default Behavior

Swift Testing runs tests in **parallel by default** for maximum performance:

```swift
// These tests run in parallel automatically
@Test func test1() async {
    await performOperation1()
}

@Test func test2() async {
    await performOperation2()
}

@Test func test3() async {
    await performOperation3()
}
```

### Serialized Execution

Use `.serialized` trait when tests must run sequentially:

```swift
// Run all tests in suite one at a time
@Suite(.serialized)
struct DatabaseTests {
    @Test func insertRecord() { }
    @Test func updateRecord() { }
    @Test func deleteRecord() { }
}

// Serialize parameterized test cases
@Suite(.serialized)
struct CupcakeTests {
    @Test(arguments: [...])
    func mixingIngredients(_ ingredient: Ingredient) { }
}
```

### Actor Isolation

```swift
// Test isolated to MainActor
@Test
@MainActor
func uiRelatedTest() {
    // Runs on main actor
}

// Test with custom actor
actor DatabaseActor {
    func query() async -> [Record] { [] }
}

@Test func databaseQuery() async {
    let db = DatabaseActor()
    let results = await db.query()
    #expect(!results.isEmpty)
}
```

---

## Test Best Practices Summary

### DO:
✅ Use Swift Testing for all new unit tests  
✅ Use `#expect` for most checks  
✅ Use `#require` when test should stop on failure  
✅ Use parameterized tests to reduce duplication  
✅ Organize tests in logical suites (structs)  
✅ Use tags to group related tests across files  
✅ Add display names for clarity  
✅ Use `withKnownIssue` for temporary failures  
✅ Use confirmations for callback testing  
✅ Leverage async/await for async tests  
✅ Use traits to customize test behavior  
✅ Add accessibility identifiers to all UI elements  

### DON'T:
❌ Don't use XCTest for new unit tests  
❌ Don't use `#available` inside test bodies (use `@available` on function)  
❌ Don't share mutable state between tests  
❌ Don't use for-loops for parameterized testing  
❌ Don't skip accessibility testing  
❌ Don't proceed with failing tests  
❌ Don't write tests without running them  
❌ Don't use `.disabled` when `.withKnownIssue` is more appropriate  

---

## Example: Complete Feature Implementation with Swift Testing

```swift
// Feature: User Login

import SwiftUI

struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("login_username_field")
                .accessibilityLabel("Username")
            
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("login_password_field")
                .accessibilityLabel("Password")
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .accessibilityIdentifier("login_error_message")
                    .accessibilityLabel("Error: \(error)")
            }
            
            Button("Login") {
                performLogin()
            }
            .disabled(isLoading || username.isEmpty || password.isEmpty)
            .accessibilityIdentifier("login_submit_button")
            .accessibilityLabel("Login")
            .accessibilityHint("Tap to log in with your credentials")
        }
        .padding()
    }
    
    /// Performs login with current credentials
    private func performLogin() {
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter both username and password"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Login logic here
        // For now, mock success
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isLoading = false
        }
    }
}

// UNIT TESTS (Swift Testing)
import Testing
@testable import MyApp

@Suite("Login View Model Tests")
struct LoginViewModelTests {
    
    @Test("Login with valid credentials succeeds")
    func loginValidCredentials() async throws {
        let viewModel = LoginViewModel()
        let result = try await viewModel.login(
            username: "user@example.com",
            password: "SecurePass123"
        )
        #expect(result.isSuccess)
    }
    
    @Test("Login with invalid credentials fails")
    func loginInvalidCredentials() async throws {
        let viewModel = LoginViewModel()
        #expect(throws: LoginError.invalidCredentials) {
            try await viewModel.login(
                username: "user@example.com",
                password: "wrong"
            )
        }
    }
    
    @Test("Login with empty username fails")
    func loginEmptyUsername() async throws {
        let viewModel = LoginViewModel()
        #expect(throws: LoginError.emptyUsername) {
            try await viewModel.login(username: "", password: "password")
        }
    }
    
    @Test("Login with empty password fails")
    func loginEmptyPassword() async throws {
        let viewModel = LoginViewModel()
        #expect(throws: LoginError.emptyPassword) {
            try await viewModel.login(username: "user@example.com", password: "")
        }
    }
    
    @Test("Multiple failed login attempts are tracked")
    func failedLoginAttempts() async throws {
        let viewModel = LoginViewModel()
        
        for _ in 0..<3 {
            _ = try? await viewModel.login(username: "user", password: "wrong")
        }
        
        #expect(viewModel.failedAttempts == 3)
    }
}

@Suite("Login Validation Tests", .tags(.unit))
struct LoginValidationTests {
    
    @Test("Email validation", arguments: [
        ("user@example.com", true),
        ("invalid-email", false),
        ("user@", false),
        ("@example.com", false),
        ("", false)
    ])
    func emailValidation(email: String, isValid: Bool) {
        let validator = LoginValidator()
        #expect(validator.isValidEmail(email) == isValid)
    }
    
    @Test("Password strength validation", arguments: [
        ("SecurePass123", true),
        ("weak", false),
        ("12345678", false),
        ("NoNumbers", false),
        ("", false)
    ])
    func passwordStrength(password: String, isStrong: Bool) {
        let validator = LoginValidator()
        #expect(validator.isStrongPassword(password) == isStrong)
    }
}

// UI TESTS (XCTest - for UI automation)
import XCTest

class LoginUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testUI_loginView_submitButtonDisabled_whenFieldsEmpty() {
        let usernameField = app.textFields["login_username_field"]
        let passwordField = app.secureTextFields["login_password_field"]
        let loginButton = app.buttons["login_submit_button"]
        
        XCTAssertTrue(usernameField.exists)
        XCTAssertTrue(passwordField.exists)
        XCTAssertFalse(loginButton.isEnabled)
    }
    
    func testUI_loginView_submitButtonEnabled_whenFieldsFilled() {
        let usernameField = app.textFields["login_username_field"]
        usernameField.tap()
        usernameField.typeText("testuser")
        
        let passwordField = app.secureTextFields["login_password_field"]
        passwordField.tap()
        passwordField.typeText("password123")
        
        let loginButton = app.buttons["login_submit_button"]
        XCTAssertTrue(loginButton.isEnabled)
    }
    
    func testAccessibility_loginView_allElementsLabeled() {
        let usernameField = app.textFields["login_username_field"]
        XCTAssertTrue(usernameField.exists)
        XCTAssertEqual(usernameField.label, "Username")
        
        let passwordField = app.secureTextFields["login_password_field"]
        XCTAssertTrue(passwordField.exists)
        XCTAssertEqual(passwordField.label, "Password")
        
        let loginButton = app.buttons["login_submit_button"]
        XCTAssertTrue(loginButton.exists)
        XCTAssertEqual(loginButton.label, "Login")
    }
}
```

---

## Metrics to Maintain

Target performance:
- ✓ Test coverage: >80%
- ✓ First-run test pass rate: >80%
- ✓ Average debug attempts: <2
- ✓ Human intervention: <10% of features
- ✓ All new unit tests use Swift Testing
- ✓ All UI elements have accessibility identifiers
- ✓ Parameterized tests used where applicable

---

## Migration from XCTest to Swift Testing

### Quick Reference

| XCTest | Swift Testing |
|--------|---------------|
| `class MyTests: XCTestCase` | `struct MyTests` |
| `func testExample()` | `@Test func example()` |
| `XCTAssertEqual(a, b)` | `#expect(a == b)` |
| `XCTAssertTrue(condition)` | `#expect(condition)` |
| `XCTAssertNil(value)` | `#expect(value == nil)` |
| `XCTUnwrap(optional)` | `try #require(optional)` |
| `XCTAssertThrowsError(try fn())` | `#expect(throws: Error.self) { try fn() }` |
| `setUp()` | `init()` |
| `tearDown()` | `deinit` (class/actor only) |
| `XCTestExpectation` | `confirmation()` |
| `continueAfterFailure = false` | Use `#require` instead of `#expect` |

### Migration Strategy

1. **New unit tests**: Always use Swift Testing
2. **Existing unit tests**: Migrate incrementally
3. **UI tests**: Keep using XCTest (XCUITest) - **Swift Testing doesn't support UI automation**
4. **Performance tests**: Keep using XCTest (XCTMetric) - **Swift Testing doesn't support performance testing**
5. **Objective-C tests**: Keep using XCTest - **Swift Testing is Swift-only**
6. **Both frameworks**: Can coexist in same target

---

## Quick Start Checklist

When starting a new Swift project with testing:

### Project Setup
- [ ] Add Testing module (included with Xcode 16+)
- [ ] Create test target with Swift Testing template
- [ ] Set up test tags for organization
- [ ] Configure test plans if needed

### For Each Feature
- [ ] Write implementation code
- [ ] Write Swift Testing unit tests simultaneously
- [ ] Add accessibility identifiers to UI elements
- [ ] Write XCUITest tests for UI flows
- [ ] Run `swift test` and verify all pass
- [ ] Check test coverage (aim for >80%)
- [ ] Document complex test scenarios

### Test Organization
- [ ] Group related tests in suites (structs)
- [ ] Use nested suites for hierarchical organization
- [ ] Apply tags for cross-cutting concerns
- [ ] Use parameterized tests to reduce duplication
- [ ] Add display names for clarity

---

## Common Patterns Quick Reference

### Basic Test
```swift
@Test func featureName() {
    let result = performOperation()
    #expect(result == expectedValue)
}
```

### Async Test
```swift
@Test func asyncFeature() async throws {
    let result = try await performAsyncOperation()
    #expect(result != nil)
}
```

### Parameterized Test
```swift
@Test(arguments: ["value1", "value2", "value3"])
func processValue(_ value: String) {
    let result = process(value)
    #expect(result.isValid)
}
```

### Error Testing
```swift
@Test func errorHandling() throws {
    #expect(throws: SpecificError.self) {
        try throwingFunction()
    }
}
```

### Suite with Setup
```swift
struct FeatureTests {
    let dependency: Dependency
    
    init() async throws {
        dependency = try await Dependency.create()
    }
    
    @Test func feature() async throws {
        // Use dependency
    }
}
```

---

## Summary

**Every feature = Code + Swift Testing Tests + Accessibility + Verification**

### Do NOT:
❌ Write code without tests
❌ Use XCTest for new unit tests
❌ Design UI without accessibility from the start
❌ Add accessibility as an afterthought
❌ Skip accessibility identifiers, labels, or hints
❌ Proceed with failing tests
❌ Ignore compilation warnings
❌ Use for-loops instead of parameterized tests
❌ Share mutable state between tests
❌ Mix XCTest and Swift Testing assertions
❌ Use Swift Testing for UI automation (use XCTest)
❌ Use Swift Testing for performance testing (use XCTest)
❌ Create UI elements without proper accessibility traits
❌ Use color alone to convey information
❌ Make touch targets smaller than 44x44 points

### DO:
✅ Write Swift Testing tests simultaneously with code  
✅ Run tests immediately after writing  
✅ Debug both code and tests in parallel  
✅ Design accessibility into every UI element from the start
✅ Include accessibility identifiers, labels, and hints in initial design  
✅ Use `#expect` for most checks  
✅ Use `#require` when test should stop on failure  
✅ Use parameterized tests to reduce duplication  
✅ Organize tests in logical suites  
✅ Use tags for cross-cutting organization  
✅ Document your work  
✅ Leverage async/await for async tests  
✅ Use traits to customize test behavior
✅ Verify accessibility with VoiceOver and assistive technologies
✅ Ensure sufficient color contrast and adequate touch targets
✅ Follow logical reading order and semantic structure

---

## Additional Resources

### Official Documentation
- [Swift Testing Package Index](https://swiftpackageindex.com/swiftlang/swift-testing/main/documentation/testing)
- [Swift Testing GitHub](https://github.com/swiftlang/swift-testing)
- [Apple Testing Documentation](https://developer.apple.com/documentation/testing)
- [XCTest Documentation](https://developer.apple.com/documentation/xctest)

### WWDC Sessions
- WWDC 2024: "Meet Swift Testing"
- WWDC 2024: "Go further with Swift Testing"
- WWDC 2023: "Fix failures faster with Xcode test reports"

### Key Concepts
- **Test Functions**: Marked with `@Test`, can be global or in types
- **Expectations**: `#expect` (continues) and `#require` (stops on failure)
- **Traits**: Customize behavior (tags, conditions, time limits, etc.)
- **Suites**: Organize tests (structs recommended for value semantics)
- **Parameterization**: Run same test with different inputs
- **Parallel Execution**: Tests run in parallel by default
- **Confirmations**: Replacement for XCTestExpectation

### Swift Testing Limitations
- **UI Testing**: Use XCTest with XCUIApplication (Swift Testing doesn't support UI automation)
- **Performance Testing**: Use XCTest with XCTMetric (Swift Testing doesn't support performance testing)
- **Objective-C**: Swift Testing is Swift-only (use XCTest for Objective-C tests)
- **Mixed Assertions**: Don't mix XCTest and Swift Testing assertions in same test

---

**Remember: In Foundation, untested code doesn't exist. Use Swift Testing for all new tests.**