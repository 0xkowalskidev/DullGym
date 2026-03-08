# DullGym

A no-nonsense local workout tracking app for Android.

## Project Overview

Track workouts, manage custom exercises, visualize progress. No cloud, no sync, no monetization. Data stays on device with CSV export capability.

### Core Features

- **Workout tracking**: Log workouts with exercises, sets, reps, weight, duration
- **Exercise CRUD**: Users can add/edit/delete custom exercises
- **Exercise types**: Support for rep-based, timed, and weighted exercises
- **Progress graphs**: Simple visualizations of user progress over time
- **CSV export**: Export all data for backup or analysis

### Tech Stack

- **Framework**: Flutter (cross-platform, targeting Android)
- **Database**: SQLite (with sqflite package)
- **Charts**: fl_chart
- **Build**: Nix flake for reproducible dev environment

### Target

- Android only (Play Store in future)
- Sideloading for personal use initially

---

## Developer Tenets

Follow these principles in all code contributions.

### 1. Verbose Naming

Names should be self-documenting. No abbreviations unless universally understood.

```dart
// YES
int totalRepetitionsCompleted;
void saveWorkoutToDatabase() {}
class ExerciseRepetitionRecord {}

// NO
int totReps;
void saveWkt() {}
class ExRepRec {}
```

### 2. Locality of Behavior

Keep related code together. A reader should understand what code does by looking at it in one place, not by jumping across files.

- Put helper functions near where they're used
- Avoid deep abstraction hierarchies
- Widget code, styling, and logic can coexist if it aids understanding

### 3. No Over-Extraction

Don't abstract prematurely. Three similar lines are often better than a generic helper.

- Extract only when there's actual duplication (3+ occurrences)
- Avoid "util" files that become junk drawers
- A longer file is fine if it's cohesive

### 4. Simplicity and Low Line Count

Every line should earn its place. Less code means fewer bugs.

- Delete dead code immediately
- No speculative features
- No backwards-compatibility shims—just change the code

### 5. Readability First

Code is read more than written. Optimize for the reader.

- Straightforward control flow over clever tricks
- Consistent formatting
- Comments explain *why*, not *what* (the code shows what)

### 6. Explicit Over Implicit

Make behavior obvious. Hidden magic causes debugging nightmares.

```dart
// YES
final workoutDurationInSeconds = 3600;
saveWorkout(workout, shouldValidate: true);

// NO
final duration = 3600; // seconds? milliseconds?
saveWorkout(workout); // does it validate? who knows
```

### 7. Fail Loudly

Errors should be visible and informative. Never swallow exceptions silently.

```dart
// YES
if (exercise == null) {
  throw StateError('Exercise not found: $exerciseId');
}

// NO
if (exercise == null) return; // silent failure, good luck debugging
```

### 8. Don't Be Lazy

- Read existing code before modifying
- Test your changes
- Handle edge cases
- Write the boring code that makes things work reliably

### 9. Refactor Relentlessly

Continuously look for opportunities to improve. Every change is a chance to leave the code better.

- Reduce line count when possible
- Simplify convoluted logic you encounter
- Remove duplication as it emerges
- Rename things when better names become obvious
- Don't defer cleanup—do it now while context is fresh
