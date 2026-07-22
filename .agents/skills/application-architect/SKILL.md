
---
name: Application Architect
description: Expert in iOS, iPadOS, tvOS, macOS MVVM architecture with SwiftUI, including proper structuring of Views, ViewModels, Services, and dependency injection using Factory
version: 1.0.0
trigger_keywords: architecture, structure, mvvm, view model, service, dependency injection, factory
---

# Application Architect Skill

## Purpose
Use this skill when architecting iOS, iPadOS, tvOS, and macOS features, structuring code, creating new Views/ViewModels/Services, or reviewing architecture compliance for this SwiftUI + MVVM application.

## When to Use
- User asks to create a new feature or screen, or do a task or a job
- User mentions "architecture", "structure", "MVVM", "view model", "service"
- User needs guidance on where to place code
- User asks about dependency injection
- User wants to refactor code to follow architecture patterns
- User needs to set up unit tests

## Technology Stack

### Platform & Languages
- **Language**: Swift 6
- **UI Framework**: SwiftUI
- **Concurrency**: Swift structured concurrency (async/await)
- **Dependency Injection**: Factory (https://github.com/hmlongco/Factory)
- **Testing**: SwiftTesting framework
- **Database**: SwiftData framework

### Architecture Pattern
**MVVM (Model-View-ViewModel) + Services**
- **View**: UI layer (SwiftUI)
- **ViewModel**: Business logic for a specific view
- **Services**: Reusable logic injected into ViewModels
- **All components**: Must have unit tests (Services and ViewModels)

## Architecture Rules

### 1. Services

Services contain reusable business logic.

**Requirements:**
- Separate file: `${NAME}Service.swift`
- Protocol constrained to `AnyObject`
- Implementation as `actor`
- Dependencies injected via Factory DI
- Registered in `FactoryKit.Container` as singleton
- Must have unit tests

**Template:**

```swift
import FactoryKit
// Protocol for service
protocol SomeServiceInterface: AnyObject { 
    func someFunction() async -> SomeType
}

// Service implementation 
actor SomeService: SomeServiceInterface { 
    // Inject other services if needed 
    // @Injected(.anotherService) private var anotherService

    func someFunction() async -> SomeType {
    }
}

// Registration in DI container as singleton 
extension FactoryKit.Container { 
    @MainActor var someService: Factory { 
        self { SomeService() }.singleton
    }
}
```

### 2. ViewModels

ViewModels contain business logic for specific views.

**Requirements:**
- Separate file: `${NAME}ViewModel.swift`
- Must be under `@Observable` Swift Macro
- Must be `final class`
- Services injected via Factory
- Must have unit tests

**Template:**

```swift
import FactoryKit

@Observable
final class SomeViewModel {

    @Injected(\.someService) private var someService

    var text: String = ""
    private var nonObservableProperty = false

    func someFunction() async {
        let someResult = await someService.someFunction()
        text = "\(someResult)"
    }
}
```

### 3. Views

Views are pure UI components.

**Requirements:**
- Separate file: `${NAME}View.swift`
- Must be SwiftUI `View`
- Create ViewModel with `@State`
- Read all data from ViewModel (no business logic in View)
- Exception: Bindings for parent views can be created in View
- Must have SwiftUI Preview with test/mock data
- Split complex Views into subviews in separate files

**Template:**

```swift
// No data from parent view
struct SomeView: View {
    @State private var viewModel = SomeViewModel()

    var body: some View {
        Text(viewModel.text)
        Button("Button") {
            viewModel.userAction()
        }
    }
}
// Constant data from parent view needed to ViewModel
struct SomeView2: View {
    
    @State private var viewModel: SomeViewModel
    
    init(parentValue: Value) {
        _viewModel = State(
            wrappedValue: SomeViewModel(parentValue: parentValue)
        )
    }

    var body: some View {
        Text(viewModel.text)
    }
}
// Binding data from parent view needed to ViewModel
struct SomeView3: View {

    @Binding var parentValue: Value
    @State private var viewModel = SomeViewModel()

    var body: some View {
        Text(viewModel.text)
            .onChange(of: parentValue) {
                viewModel.someFunction(parentValue)
            }
            .task {
                viewModel.someFunction(parentValue)
            }
    }
}
// Data from parent view NOT needed to ViewModel
struct SomeView4: View {

    @Binding var parentValue: Value
    @State private var viewModel = SomeViewModel()

    var body: some View {
        Button("Button") {
            parentValue.toggle()
        }
    }
}

// SwiftUI Preview for a each view
#Preview { 
    let _ = Container.shared.someService.register { SomeServiceMock() }
    SomeView()
}
private actor SomeServiceMock: SomeServiceInterface { 
    func someFunction() async -> SomeType { }
}
```

## Directory Structure

### Feature Organization

Each feature gets its own directory:

/{Feature}/ ├──{Feature}ViewModel.swift ├── {Feature}View.swift # Subviews if needed └── ${Feature}View1.swift

### Services Organization

All services in dedicated directory:

/Services/ └── ${ServiceName}Service.swift

### Tests Organization

Mirror structure in tests target:

/{Feature}/ └──{Feature}ViewModelTests.swift /Services/ └── ${ServiceName}ServiceTests.swift

## Workflow: Creating a New Feature

When a user asks to create a new feature (e.g., "UserProfile"):

1. **Create Service** (if needed for reusable logic):
    - File: `/Services/UserProfileService.swift`
    - Protocol + Actor implementation
    - Register in `FactoryKit.Container`
    - Write unit tests: `/Services/UserProfileServiceTests.swift`

2. **Create ViewModel**:
    - File: `/UserProfile/UserProfileViewModel.swift`
    - `final class` + `@Observable` Swift Macro
    - Inject services with `@Injected`
    - Write unit tests: `/UserProfile/UserProfileViewModelTests.swift`

3. **Create View**:
    - File: `/UserProfile/UserProfileView.swift`
    - SwiftUI `View`
    - `@State` for ViewModel
    - SwiftUI Preview with mocks
    - Split into subviews if complex

## Key Principles

✅ **DO:**
- Always follow MVVM separation
- Use dependency injection for all services
- Write unit tests for Services and ViewModels
- Use async/await for concurrency
- Create SwiftUI Previews with mock data
- Keep Views simple (UI only)
- Put business logic in ViewModels
- Put reusable logic in Services

❌ **DON'T:**
- Put business logic in Views
- Create ViewModels without tests
- Create Services without tests
- Access services directly from Views

## Reference Examples

For complete examples, refer to:
- Service: `./examples/Services/FilesService.swift`
- ViewModel: `./examples/Files/FilesViewModel.swift`
- View: `./examples/Files/FilesView.swift`
- Service Tests: `./examples/UnitTests/Services/FilesServiceTests.swift`
- ViewModel Tests: `./examples/UnitTests/Files/FilesViewModelTests.swift`
