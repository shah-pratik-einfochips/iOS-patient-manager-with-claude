
NOTE: This is a read-only file. Do not modify it.

## Requirement Gathering
*  Collaborate with stakeholders to capture functional & non-functional requirements.
* Prepare user stories, acceptance criteria, and feature backlog.
* Conduct feasibility analysis for iOS platform limitations (e.g., background tasks, push notifications, iCloud sync).
* Collect performance/security expectations to be considered in the architecture phase.
* Create requirement traceability matrix to map business needs with app features.


## Design & Documentation
* Design application architecture (MVVM, VIPER, or Clean Architecture) considering scalability.
* Create UI/UX wireframes, flow diagrams, and navigation architecture.
* Define data flow diagrams, sequence diagrams, and class structures.
* Document technical decisions including frameworks, third-party dependencies, and libraries.
* Provide developer onboarding documentation with coding standards and project guidelines.



## Application Setup & Code Generation
* Create a new iOS application using Xcode with modularized folder/package structure.
* Define app targets and build configurations for multiple environments (Dev, QA, Prod).
* Integrate Swift Package Manager for dependency management.
* Configure SwiftData/Realm data models with entity relationships.
* Implement initial navigation using Coordinator/Navigation stack.
* Set up App Signing & Provisioning profiles for development and distribution.
* Implement code generation tools (e.g., SwiftGen for assets/localization, Sourcery for boilerplate code).
* Establish coding guidelines and reusable templates/snippets to accelerate feature development.



## Code Analysis, Refactoring & Enhancement
* Perform SwiftLint / SonarQube analysis for code quality and maintainability.
* Refactor duplicate/legacy code into reusable modules.
* Review code for memory leaks using Instruments (Leaks, Allocations).
* Suggest modularization ensuring scalability and backward compatibility.
* Apply coding standards to improve readability and long-term maintainability.


## Unit Testing Automation
* Configure XCTest framework for unit testing.
* Develop positive and negative test cases for critical modules.
* Implement snapshot/UI testing for UI consistency.
* Analyze code coverage and generate reports using Xcode.
* Document test cases with pass/fail reports for QA team.



## Migration & Compatibility
* Migrate project from Objective-C to Swift (where applicable).
* Upgrade iOS deployment target to latest stable version ensuring compatibility.
* Update third-party libraries to latest versions.
* Resolve Swift language migration issues (Swift 4 → 5.x).
* Validate compatibility across multiple iOS versions and devices.


## Consulting – SOLID principles & Best Practices
* Review codebase for SOLID violations and recommended modular refactoring.
* Suggest dependency injection, reactive programming (Combine), and Swift Concurrency (async/await).
* Recommend reusable UI components using SwiftUI/UIKit.
* Document coding standards for scalable iOS projects.
* Propose guidelines for error handling, logging, and crash reporting.



## Analysis of Potential Performance Issues
* Identify bottlenecks using Instruments (Time Profiler, Energy Log).
* Optimize SwiftData fetch requests and reduced N+1 queries.
* Prevent heavy UI rendering on main thread (moved to background threads).
* Implement image caching if required.
* Reduce app launch time by lazy-loading heavy modules.
* Replace synchronous calls with async/await or GCD for responsiveness.