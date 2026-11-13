---
name: flutter-expert
description: Production engineering standard for writing ultra-concise, modern, and maximum-performance Flutter 3.50 and Dart 3.14+ code. Automatically apply when creating, refactoring, optimizing, or reviewing Flutter widgets, slivers, state management, CustomPainters, FragmentShaders, 3D Matrix4 projections, SIMD (v128) pipelines, Direct Native Interop (JNIgen/FFIgen/Native Assets), isolates, or WebAssembly (--wasm) builds.
---

# Flutter 3.50 & Dart 3.14+ High-Performance Engineering Standard

Write idiomatic, minimal-boilerplate, and performance-obsessed Flutter 3.50 (Dart 3.14+) code. Every widget tree, layout pass, and frame callback must minimize rebuild scope, eliminate per-frame heap allocations, and maximize Impeller and WebAssembly (`dart2wasm`) hardware throughput.

---

## 1. Concise Modern Dart 3.14+ Syntax

Always use modern Dart language features to eliminate boilerplate while maintaining strict static type safety.

### A. Dot-Shorthand Syntax (Dart 3.10+)
Omit redundant type prefixes whenever the target type is statically known from the parameter or variable context (enums, static constants, and factory constructors owned directly by the static target type):

```dart
// PREFERRED: Context-inferred dot-shorthands
Container(
  alignment: .center,
  padding: const .symmetric(horizontal: 16, vertical: 12),
  margin: .zero,
  decoration: BoxDecoration(
    color: const .fromRGBO(18, 22, 30, 1),
    borderRadius: const .all(.circular(12)),
  ),
  child: Row(
    mainAxisAlignment: .spaceBetween,
    crossAxisAlignment: .center,
    children: [
      Image.network(url, fit: .cover, filterQuality: .medium),
      // GUARDRAIL: Keep explicit prefix when constant lives on a helper class!
      // `Icons` != `IconData` and `Colors` != `Color`.
      const Icon(Icons.check_circle_rounded, color: Colors.tealAccent, size: 20),
    ],
  ),
)
```

### B. Primary / Declaring Constructors (Dart 3.13+)
Use primary constructors for concise immutable models, state classes, and `const`-capable widgets without repeating field declarations. Place `const` between `class` and the class name, and terminate body-less classes with `;`:

```dart
// PREFERRED: Constant primary constructor on immutable domain model
final class const ViewportMetrics(
  final double width,
  final double height,
  final double devicePixelRatio,
) {
  double get physicalWidth => width * devicePixelRatio;
}

// PREFERRED: Constant primary constructor on StatelessWidget with super.key
class const MetricBadge(
  final String label,
  final String value, {
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(borderRadius: .all(.circular(8))),
    child: Padding(
      padding: const .all(8),
      child: Text('$label: $value'),
    ),
  );
}
```

### C. Null-Aware Collection Elements (Dart 3.12+)
Compose conditional widget lists and maps directly using `?element`, `?key: value`, and `key: ?value` instead of verbose `if (x != null)` checks or `.whereType<Widget>()`:

```dart
// PREFERRED: Null-aware elements in widget lists
Column(
  crossAxisAlignment: .start,
  children: [
    const SectionHeader(title: 'Telemetry'),
    ?subtitleWidget,
    if (isLive) ?liveIndicatorBadge,
    for (final item in items) ItemTile(key: ValueKey(item.id), item: item),
  ],
)
```

### D. Records, Exhaustive Pattern Matching & Extension Types
- **Typed Records:** Return multiple values via `({double x, double y, double z})` instead of single-use wrapper classes.
- **Exhaustive `switch` Expressions:** Map single-line `sealed` primary constructor hierarchies directly to widgets or values.
- **Zero-Cost Extension Types:** Wrap primitive domain units (`Radians`, `Milliseconds`, `EntityId`) to enforce type safety with zero heap wrapper allocation:

```dart
extension type const Radians(double value) implements double {
  double get toDegrees => value * (180.0 / 3.141592653589793);
}

sealed class const LoadState<T>();
final class const Loading<T>() extends LoadState<T>;
final class const Ready<T>(final T data) extends LoadState<T>;
final class const Failure<T>(final String message) extends LoadState<T>;

Widget buildStateView(LoadState<String> state) => switch (state) {
  Loading() => const CircularProgressIndicator(),
  Ready(:final data) => Text(data),
  Failure(:final message) => ErrorBanner(message: message),
};
```

### E. Strict Static & API Hygiene
- **Zero `dynamic` Policy:** Never use `dynamic` or unchecked casts. Use `Object?`, constrained generics, `sealed` hierarchies, or typed records.
- **Modern Flutter APIs Only:**
  * Use `color.withValues(alpha: 0.5)` — never deprecated `color.withOpacity(0.5)`.
  * Use `PopScope<T>` — never deprecated `WillPopScope`.
  * Use `WidgetStateProperty` / `WidgetState` — never legacy `MaterialStateProperty`.

---

## 2. Widget Tree, Rebuild Isolation & Sliver Virtualization

### A. Granular Reactive Scopes
Never call `setState()` high in a widget tree when only a leaf widget changes. Isolate high-frequency updates (scroll offsets, drag deltas, timers, audio/sensor streams) using `ValueNotifier<T>` + `ValueListenableBuilder<T>` or `ListenableBuilder`, and always pass static subtrees via the `child:` parameter:

```dart
// PREFERRED: Leaf-only rebuild with cached static child
ValueListenableBuilder<double>(
  valueListenable: progressNotifier,
  child: const HeavyStaticBackdrop(),
  builder: (context, progress, staticChild) => Stack(
    fit: .expand,
    children: [
      ?staticChild,
      FractionallySizedBox(
        alignment: .centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: const ProgressBarFill(),
      ),
    ],
  ),
)
```

### B. `const` Everywhere & Class Decomposition Over Helper Methods
- Mark every eligible constructor, widget, `EdgeInsets`, `BoxDecoration`, `BorderRadius`, and `TextStyle` as `const` so `Element.update` short-circuits in $O(1)$ via `identical(oldWidget, newWidget)`.
- **Never extract UI into `_buildSection()` helper methods.** Extract small private `StatelessWidget` classes (`class const _HeaderSection(...)`) so Flutter tracks `Element` identity and repaint boundaries independently.

### C. High-Efficiency Viewports, Slivers & Grouped Blurs
- **Never use `shrinkWrap: true`** on `ListView` or `GridView` inside another scrollable. Compose a single `CustomScrollView` with lazy slivers.
- Always provide `itemExtent` (`SliverFixedExtentList.builder`), `prototypeItem` (`SliverPrototypeExtentList.builder`), or `itemExtentBuilder` (`SliverVariedExtentList.builder`) to bypass $O(N)$ intrinsic layout measurement passes.
- When multiple glassmorphic widgets share a blur backdrop, wrap their ancestor in `BackdropGroup` and use `BackdropFilter.grouped` to merge multiple GPU blur passes into one:

```dart
BackdropGroup(
  child: CustomScrollView(
    cacheExtent: 600,
    slivers: [
      const SliverAppBar(pinned: true, title: Text('Telemetry Stream')),
      SliverFixedExtentList.builder(
        itemExtent: 72,
        itemCount: records.length,
        itemBuilder: (context, index) => RecordRow(
          key: ValueKey(records[index].id),
          record: records[index],
        ),
      ),
    ],
  ),
)
```

---

## 3. Impeller Rendering, 3D Matrix Math & Zero-Allocation Hot Paths

### A. Zero Heap Allocations Inside `paint()` and `Ticker` Callbacks
At 120 Hz, the total frame budget is **8.33 ms**. Never instantiate mutable heap objects (`Paint`, `Path`, `Matrix4`, `Float64List`, `PictureRecorder`, `Gradient`, or `List`) inside `CustomPainter.paint()`, `RenderBox.paint()`, or animation tick callbacks. Pre-allocate and mutate in place:

```dart
final class ZeroAllocWavePainter extends CustomPainter {
  ZeroAllocWavePainter({required this.phase}) : super(repaint: phase);

  final ValueListenable<double> phase;

  final Paint _strokePaint = Paint()
    ..style = .stroke
    ..strokeWidth = 2.0
    ..strokeCap = .round
    ..isAntiAlias = true
    ..color = const .fromRGBO(0, 229, 255, 1);

  final Path _wavePath = Path();

  @override
  void paint(Canvas canvas, Size size) {
    _wavePath.reset();
    final midY = size.height * 0.5;
    _wavePath.moveTo(0, midY);
    // Populate _wavePath from pre-allocated ring buffer...
    canvas.drawPath(_wavePath, _strokePaint);
  }

  @override
  bool shouldRepaint(ZeroAllocWavePainter oldDelegate) =>
      oldDelegate.phase != phase;
}
```

### B. Pre-Allocated 3D Perspective & `Matrix4` Transformations
When rendering 3D carousels, cylindrical galleries, or perspective cards:
- Pre-allocate `Matrix4` buffers in `State` or the painter and mutate entries directly (`setIdentity()`, `setEntry(3, 2, perspective)`, `rotateY()`, `translate()`) rather than allocating chained `Matrix4` instances per widget per frame.
- Perform backface culling ($\cos(\theta) \le 0$) and depth sorting ($Z$-order) on lightweight index buffers before building or painting visible cards.

### C. Batch Canvas Primitives & `saveLayer()` Elimination
- **Batch Draw Calls:** Prefer `Canvas.drawRawPoints`, `Canvas.drawRawAtlas`, or `Canvas.drawVertices` (backed by pre-allocated `Float32List` / `Int32List` buffers) over hundreds of individual `drawCircle` or `drawRect` calls.
- **Eliminate `saveLayer()` Stalls:**
  * Never wrap animated subtrees in `Opacity` (or `AnimatedOpacity` when avoidable, as `RenderAnimatedOpacity` still invokes `saveLayer` at intermediate alpha values). Use `FadeTransition` (compositor `OpacityLayer`) or direct color/image alpha modulation (`color.withValues(alpha: a)`).
  * Never use `Clip.antiAliasWithSaveLayer`; use `Clip.antiAlias` or `BoxDecoration(borderRadius: ...)`.
- **Strategic `RepaintBoundary`:** Isolate high-frequency `CustomPaint` canvases and continuous animations inside a `RepaintBoundary` so static sibling layers remain cached in Impeller textures.

### D. Fragment Shaders (`ui.FragmentProgram`)
Load `FragmentProgram.fromAsset('shaders/effect.frag')` **once** during initialization, cache the reusable `FragmentShader` instance, and only update uniform floats (`shader.setFloat(index, value)`) inside `paint()`.

---

## 4. SIMD (`v128`), Concurrency, Direct Native Interop & WebAssembly (`--wasm`)

### A. 128-Bit SIMD Acceleration (`Float32x4List`) for Native & WebAssembly
Dart 3.14 (`flutter build web --wasm`) compiles `Float32x4`, `Int32x4`, `Float32x4List`, and `Int32x4List` (`dart:typed_data`) directly to **WebAssembly 128-bit SIMD (`v128`)** hardware instructions as well as ARM NEON and x86 SSE on native targets. Use 4-lane SIMD vectors for particle physics, 3D vertex projection, layout solvers, and real-time signal processing (DAQ/DSP):

```dart
import 'dart:typed_data';

void integrateParticlesSimd({
  required Float32x4List positions,
  required Float32x4List velocities,
  required double dt,
}) {
  final dtVec = Float32x4.splat(dt);
  final count = positions.length;
  for (var i = 0; i < count; i++) {
    positions[i] += velocities[i] * dtVec;
  }
}
```

### B. Zero-Copy Concurrency (`Isolate.run` & `TransferableTypedData`)
- Offload heavy JSON parsing, cryptographic encryption (RSA/AES), image processing, and binary frame decoding from the UI isolate using `Isolate.run(...)`.
- Wrap large `Uint8List` / `Float32List` buffers in `TransferableTypedData.fromList([buffer])` when crossing isolate boundaries to achieve $O(1)$ zero-copy memory transfer instead of $O(N)$ serialization cloning.

### C. Direct Native Interop (`JNIgen`, `FFIgen`, `@Native` & Native Assets)
Prefer Flutter 3.50 direct native interop over serialized `MethodChannel` round-trips for new native integrations:
- **C/C++/Rust (`dart:ffi`):** Declare bindings with `@Native<NativeSignature>(isLeaf: true)` for fast synchronous functions that do not call back into Dart, bundled declaratively via `hook/build.dart` (Native Assets).
- **Android (`jnigen`) & iOS/macOS (`ffigen`):** Call Kotlin/Java and Objective-C/Swift (`@objc`) APIs directly (or via Pigeon Native Interop). Always release long-lived Android JNI references via `.release()` in `dispose()` to stay well below the JNI global reference limit.

### D. WebAssembly (`--wasm`) Strict Compatibility
Keep all cross-platform and web code 100% compatible with `flutter build web --wasm --no-deprecated-js-interop`:
- **Strictly Forbidden:** `dart:html`, `dart:js`, `dart:js_util`, `package:js`, and unguarded `dart:io` or `dart:mirrors`.
- **Required:** `package:web` for DOM/Browser APIs and static `@JS()` extension-type bindings via `dart:js_interop` (using `.toJS` / `.toDart` zero-copy typed array conversions).

---

## 5. Pre-Output Verification Checklist

Before finalizing any Flutter code response, verify all 6 gates:
1. **Syntax & Dot-Shorthands:** Dot-shorthands (`.center`, `.spaceBetween`), primary constructors (`class const`), null-aware elements (`?child`), switch expressions, and `.withValues(alpha: ...)` are used idiomatically—and `Icons.*` / `Colors.*` retain their explicit class prefixes.
2. **Const & Decomposition:** Every eligible constructor and widget is `const`; `build()` methods stay flat (< 40 lines) with zero `_build*()` helper methods.
3. **Viewport & Rebuild Scope:** High-frequency state is isolated to leaf `ValueListenableBuilder` / `ListenableBuilder` scopes; scrollables use lazy slivers with explicit extent hints (`itemExtent` / `prototypeItem`).
4. **Hot-Path Purity:** Zero mutable object allocations (`Paint`, `Path`, `Matrix4`, `List`) occur inside `paint()` or `Ticker` callbacks; animations avoid `saveLayer()`.
5. **SIMD & Wasm Readiness:** Compute-intensive numeric loops use `Float32x4List` (`v128` SIMD) or `Isolate.run`; web interop passes `--no-deprecated-js-interop` using `dart:js_interop` and `package:web` exclusively.
6. **Lifecycle Hygiene:** Every `AnimationController`, `TextEditingController`, `FocusNode`, `ScrollController`, `FragmentShader`, JNI reference (`.release()`), and `ValueNotifier` owned by a `State` is explicitly disposed in `dispose()`.