---
name: flutter-expert
description: Production engineering standard for writing ultra-concise, modern, and maximum-performance Flutter 3.50 and Dart 3.14+ code. Automatically apply when creating, refactoring, optimizing, or reviewing Flutter widgets, slivers, RepaintBoundary placement, state management, CustomPainters, FragmentShaders, 3D Matrix4 projections, SIMD (v128) pipelines, Direct Native Interop (JNIgen/FFIgen/Native Assets), isolates, or WebAssembly (--wasm) builds.
---

# Flutter 3.50 & Dart 3.14+ High-Performance Engineering Standard

Write idiomatic, minimal-boilerplate, and performance-obsessed Flutter 3.50 (Dart 3.14+) code. Every widget tree, layout pass, and frame callback must minimize rebuild scope, eliminate per-frame heap allocations, and maximize Impeller (native), Skwasm (Wasm web), and WebAssembly (`dart2wasm`) hardware throughput.

---

## 1. Concise Modern Dart 3.14+ Syntax

Always use modern Dart language features to eliminate boilerplate while maintaining strict static type safety.

### A. Dot-Shorthand Syntax (Dart 3.10+)
Omit redundant type prefixes whenever the target type is statically known from the parameter or variable context (enums, static members, and generative/factory constructors owned directly by the static target type):

```dart
// PREFERRED: Context-inferred dot-shorthands
Container(
  alignment: .center,
  padding: const .symmetric(horizontal: 16, vertical: 12),
  margin: .zero,
  decoration: const BoxDecoration(
    color: .fromRGBO(18, 22, 30, 1),
    borderRadius: .all(.circular(12)),
  ),
  child: Row(
    mainAxisAlignment: .spaceBetween,
    crossAxisAlignment: .center,
    children: [
      Image.network(url, fit: .cover, cacheWidth: 512),
      // GUARDRAIL: Keep explicit prefix when constant lives on a helper class
      // (`Icons` != `IconData`, `Colors` != `Color`) or when target type is a supertype
      // (e.g. `Decoration?` does not own `BoxDecoration`'s constructors).
      const Icon(Icons.check_circle_rounded, color: Colors.tealAccent, size: 20),
    ],
  ),
)
```

### B. Primary / Declaring Constructors (Dart 3.13+)
Use primary constructors for immutable models, state classes, and `const`-capable widgets without repeating field declarations. Place `const` between `class` and the class name, terminate body-less classes with `;`, and use `this : super(...)` / `this : assert(...)` for initializers. Only parameters prefixed with `final` (or `var`) declare instance fields; unprefixed parameters remain constructor-only. For secondary/in-body constructors, use concise `new(...)` / `factory(...)` syntax instead of repeating the class name:

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

### C. Null-Aware Collection Elements (Dart 3.8+)
Compose conditional widget lists, sets, and maps directly using `?element`, `?key: value`, and `key: ?value` instead of verbose `if (x != null)` checks or `.whereType<Widget>()`:

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
- **Zero-Cost Extension Types:** Wrap primitive domain units (`Radians`, `Milliseconds`, `EntityId`) to enforce type safety with zero heap wrapper allocation (omit `implements` when strict unit isolation is desired):

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

### E. Strict Static & Modern Flutter 3.50 API Hygiene
- **Zero `dynamic` Policy:** Never use `dynamic` or unchecked casts. Use `Object?`, constrained generics, `sealed` hierarchies, or typed records.
- **Modern Flutter 3.50 APIs Only:**
  * Use `package:material_ui/material_ui.dart` / `package:cupertino_ui/cupertino_ui.dart` (or `package:flutter/widgets.dart` for custom design systems) — never deprecated `package:flutter/material.dart` / `package:flutter/cupertino.dart` (deprecated after v3.47.0).
  * Use `scrollCacheExtent: const ScrollCacheExtent.pixels(...)` (or `.viewport(...)`) — never deprecated `cacheExtent` / `cacheExtentStyle` (deprecated after v3.41.0).
  * Use `color.withValues(alpha: 0.5)`, `.r`/`.g`/`.b`/`.a`, and `.toARGB32()` — never deprecated `.withOpacity()`, `.value`, or `.red`/`.green`/`.blue`/`.alpha`/`.opacity`.
  * Use `Matrix4.translateByDouble(...)` / `translateByVector3(...)` and `scaleByDouble(...)` / `scaleByVector3(...)` — never deprecated `Matrix4.translate()` / `Matrix4.scale()`.
  * Use `PopScope<T>` and `WidgetStateProperty` / `WidgetState` — never legacy `WillPopScope` or `MaterialStateProperty`.

---

## 2. Widget Tree, Rebuild Isolation & Sliver Virtualization

### A. Granular Reactive Scopes
Never call `setState()` high in a widget tree when only a leaf widget changes. Isolate high-frequency updates (scroll offsets, drag deltas, timers, audio/sensor streams) using `ValueNotifier<T>` + `ValueListenableBuilder<T>` or `ListenableBuilder` (with `Listenable.merge([...])` for multi-source listeners), and always pass static subtrees via the `child:` parameter. Prefer transform/paint animations over layout-invalidating properties (`FractionallySizedBox.widthFactor`) on 120 Hz hot paths:

```dart
// PREFERRED: Leaf-only rebuild with cached static child & zero per-tick relayout
ValueListenableBuilder<double>(
  valueListenable: progressNotifier,
  child: const HeavyStaticBackdrop(),
  builder: (context, progress, staticChild) => Stack(
    fit: .expand,
    children: [
      ?staticChild,
      Transform.scale(
        alignment: .centerLeft,
        scaleX: progress.clamp(0.0, 1.0),
        child: const ProgressBarFill(),
      ),
    ],
  ),
)
```

### B. `const` Everywhere, Lightweight Widgets & Class Decomposition
- Mark every eligible constructor, widget, `EdgeInsets`, `BoxDecoration`, `BorderRadius`, and `TextStyle` as `const` so `Element.update` short-circuits in $O(1)$ via `identical(oldWidget, newWidget)`.
- **Never extract UI into `_buildSection()` helper methods.** Extract small private `StatelessWidget` classes (`class const _HeaderSection(...)`) so Flutter tracks `Element` identity, `BuildContext` / `InheritedWidget` dependencies, and `const` short-circuiting independently.
- Avoid single-purpose `Container` widgets; prefer `Padding`, `DecoratedBox`, `ColoredBox`, `SizedBox`, or `Align`.
- Always specify `cacheWidth` / `cacheHeight` on `Image` widgets displaying large assets/photos to match rendered pixel bounds and prevent GPU texture memory bloat.

### C. High-Efficiency Viewports, Slivers & Grouped Blurs
- **Never use `shrinkWrap: true`** on `ListView` or `GridView` inside another scrollable. Compose a single `CustomScrollView` with lazy slivers (avoid eagerly building huge `SingleChildScrollView` + `Column` pages when sections are tall or numerous).
- Always provide `itemExtent` (`SliverFixedExtentList.builder`), `prototypeItem` (`SliverPrototypeExtentList.builder`), or `itemExtentBuilder` (`SliverVariedExtentList.builder`) to bypass $O(N)$ intrinsic layout measurement passes.
- When multiple **non-overlapping** glassmorphic widgets share an **identical** blur configuration (`bounds: null`), wrap a stable ancestor in `BackdropGroup` (caching `BackdropKey` if the ancestor rebuilds) and use `BackdropFilter.grouped` to merge multiple GPU blur passes into one:

```dart
BackdropGroup(
  backdropKey: backdropKey,
  child: CustomScrollView(
    scrollCacheExtent: const .pixels(600),
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

## 3. Impeller Rendering, `RepaintBoundary` Discipline & Zero-Allocation Hot Paths

### A. Zero Heap Allocations Inside `paint()` and `Ticker` Callbacks
At 120 Hz, the total frame budget is **8.33 ms**. Never instantiate mutable heap objects (`Paint`, `Path`, `Matrix4`, `Float64List`, `TextPainter`, `PictureRecorder`, `Gradient`, or `List`) inside `CustomPainter.paint()`, `RenderBox.paint()`, or animation tick callbacks. Pre-allocate and mutate in place—and **cache the `CustomPainter` instance in `State`** (e.g., `late final _painter = ...`) so parent rebuilds don't re-instantiate `Paint`/`Path` fields either. For complex static vector layers inside a dynamic canvas, record a `ui.Picture` **once** via `PictureRecorder` outside `paint()`, replay it with `canvas.drawPicture()`, and call `picture.dispose()` in `dispose()`:

```dart
final class ZeroAllocWavePainter({required final ValueListenable<double> phase})
    extends CustomPainter {
  this : super(repaint: phase);

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
- Pre-allocate `Matrix4` buffers in `State` or the painter and mutate entries in place (`setIdentity()`, `setEntry(3, 2, perspective)`, `rotateY()`, `translateByDouble(x, y, z, 1.0)`, `scaleByDouble(sx, sy, sz, 1.0)`) rather than allocating chained `Matrix4` instances per widget per frame. Inside `CustomPainter.paint()`, pass `_matrix.storage` directly to `canvas.transform(...)` to avoid `RenderTransform`'s internal `Matrix4.copy`.
- Perform backface culling ($\cos(\theta) \le 0$, where $\theta$ is the angle from the viewer-facing normal) and depth sorting ($Z$-order) on lightweight index buffers before building or painting visible cards.

### C. Batch Canvas Primitives, `saveLayer()` Elimination & Surgical `RepaintBoundary`
- **Batch Draw Calls:** Prefer `Canvas.drawRawPoints`, `Canvas.drawRawAtlas`, or `Canvas.drawVertices` (backed by pre-allocated `Float32List` / `Int32List` buffers) over hundreds of individual `drawCircle` or `drawRect` calls.
- **Eliminate `saveLayer()` Stalls:**
  * **Never wrap composite/multi-child subtrees in `Opacity`, `AnimatedOpacity`, or `FadeTransition` when leaf alpha works.** `Opacity`, `AnimatedOpacity` (which builds `FadeTransition`), and `FadeTransition` (`RenderAnimatedOpacity`) *all* push a compositor `OpacityLayer` at intermediate alpha (`0 < alpha < 255`); when a subtree has multiple/overlapping primitives, the engine's single-primitive peephole optimization fails and triggers an offscreen `saveLayer()` render pass.
  * **Best:** Modulate alpha directly on leaf primitives (`color.withValues(alpha: a)`, `Image(..., opacity: animation)`, `TextStyle`, or `Paint.color`).
  * **When fading a composite group is unavoidable:** Prefer `FadeTransition` (explicit `Animation<double>`) or `AnimatedOpacity` over animating `Opacity` via `setState`, because `RenderAnimatedOpacity` updates the `OpacityLayer` directly without widget rebuilds or child repaints—and keep the wrapped subtree as tight/shallow as possible. Use `Visibility.maintain` / `Visibility` (paired with `IgnorePointer` when hidden) for binary show/hide.
  * **Avoid `Clip.antiAliasWithSaveLayer`:** Use `Clip.antiAlias` or `BoxDecoration(borderRadius: ...)`.
- **Surgical `RepaintBoundary` (Avoid Layer-Overhead Bottlenecks):**
  * **How it works (Impeller vs. Skia):** `RepaintBoundary` stops `markNeedsPaint()` propagation and isolates `DisplayList` recording (`PictureLayer` / `OffsetLayer`) so static ancestors/siblings don't re-run `paint()` on the UI thread. Unlike legacy Skia, **Impeller removed the persistent `PictureLayer` raster texture cache**—do not add `RepaintBoundary` expecting Impeller to cache static subtrees as persistent offscreen GPU bitmaps.
  * **When to USE (Asymmetric Repaints):** Tightly wrap high-frequency `CustomPaint` canvases, continuous tickers, or localized animations so static siblings don't re-record; or isolate a genuinely heavy static background beneath an independently animating overlay.
  * **When to AVOID (Performance Bottlenecks):**
    1. **Symmetric / Co-Repainting Subtrees:** Never wrap parent and child when both repaint on the same frames (e.g. scroll-driven parallax sections inside a `SingleChildScrollView`, or multiple widgets listening to the same `ScrollController`/animation). Redundant boundaries degrade performance with extra layer-tree traversal, memory, and GPU compositing overhead.
    2. **Micro-Boundaries on Cheap Widgets:** Never wrap simple `Text`, `Icon`, or basic `DecoratedBox` widgets—the layer/compositing cost outweighs the trivial paint cost.
    3. **Double Boundaries in Lazy Lists:** `ListView.builder`, `GridView.builder`, and `SliverList.builder` wrap each item in `RepaintBoundary` by default (`addRepaintBoundaries: true`). Never add another `RepaintBoundary` at the item root; for ultra-lightweight rows, set `addRepaintBoundaries: false`.
    4. **Misplaced Around `Transform`:** Wrapping `RepaintBoundary` *outside* an animating `Transform` only isolates the outer tree; the `Transform` and its child still re-record together unless the heavy static child inside `Transform` is itself isolated.
    5. **Non-Paint Jank:** `RepaintBoundary` never fixes `build()` or `layout()` bottlenecks.
  * **Verify Empirically:** Audit with DevTools **Highlight Repaints** (`debugRepaintRainbowEnabled`) and inspect `RenderRepaintBoundary` `debugSymmetricPaintCount` vs. `debugAsymmetricPaintCount` via `debugDumpRenderTree()`; remove any boundary with low asymmetry.

### D. Fragment Shaders (`ui.FragmentProgram`)
Load `FragmentProgram.fromAsset('shaders/effect.frag')` **once** during initialization, create and cache the reusable `FragmentShader` via `program.fragmentShader()` (simultaneous callers with distinct uniforms need separate instances), update uniforms (`shader.setFloat(...)` / `shader.setImageSampler(...)`) inside `paint()`, and call `shader.dispose()` in `dispose()`.

---

## 4. SIMD (`v128`), Concurrency, Direct Native Interop & WebAssembly (`--wasm`)

### A. 128-Bit SIMD Acceleration (`Float32x4List`) for Native & WebAssembly
Dart 3.14 (`flutter build web --wasm`) compiles `Float32x4`, `Int32x4`, `Float64x2`, and their typed lists (`Float32x4List`, `Int32x4List`, `Float64x2List` in `dart:typed_data`) directly to **WebAssembly 128-bit SIMD (`v128`)** hardware instructions as well as ARM NEON and x86 SSE on native targets. Use 4-lane SIMD vectors for particle physics, 3D vertex projection, layout solvers, and real-time signal processing (DAQ/DSP):

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

### B. Concurrency: Native Isolates vs. Web Workers
- **Native Targets (iOS, Android, Desktop):** Offload heavy JSON parsing, cryptographic encryption (RSA/AES), image processing, and binary frame decoding from the UI isolate using `Isolate.run(...)`. Wrap large `Uint8List` / `Float32List` buffers in `TransferableTypedData.fromList([buffer])` (materialized on the worker via `.materialize()`) for $O(1)$ zero-copy transfer—do not read or mutate the source buffer after wrapping.
- **Web & `--wasm` Targets:** `dart:isolate` (`Isolate.run`, `Isolate.spawn`, `TransferableTypedData`) is **unsupported on Web** and throws `UnsupportedError` at runtime. Guard isolate usage behind `kIsWeb` / conditional imports and offload heavy web work to **Web Workers** (via `package:web` + `dart:js_interop` or a worker abstraction such as `isolate_manager`), or yield/chunk across frames.

### C. Direct Native Interop (`JNIgen`, `FFIgen`, `@Native` & Native Assets)
Prefer Flutter 3.50 direct native interop over serialized `MethodChannel` round-trips on Android, iOS, and macOS (Windows/Linux still use Platform Channels or `dart:ffi`):
- **C/C++/Rust (`dart:ffi`):** Declare bindings with `@Native<NativeSignature>(assetId: ..., isLeaf: true)` bundled declaratively via `hook/build.dart` (`package:hooks` + `package:native_toolchain_c`; use `hook/link.dart` + `@RecordUse()` for symbol tree-shaking). Only set `isLeaf: true` when the native function never calls back into Dart or accesses Dart `Handle`s.
- **Android (`jnigen`) & iOS/macOS (`ffigen`):** Call Kotlin/Java and Objective-C/Swift (`@objc`) APIs directly (or via Pigeon with `useJni: true` / `useFfi: true`). Release scoped Android JNI objects with `using((arena) { ... releasedBy(arena); })`, call `.release()` in `dispose()` on long-lived references to stay well below the JNI global reference limit, and preserve reflection/JNI targets with `@Keep` / ProGuard rules in release builds.

### D. WebAssembly (`--wasm`) Strict Compatibility
Keep all cross-platform and web code 100% compatible with `flutter build web --wasm` (which renders with **Skwasm** on WasmGC-capable browsers; add `--no-deprecated-js-interop` to enforce the same ban on the `dart2js` JS fallback):
- **Strictly Forbidden:** `dart:html`, `dart:js`, `dart:js_util`, `package:js`, and unguarded `dart:io`, `dart:isolate`, or `dart:mirrors`.
- **Required:** `package:web` for DOM/Browser APIs and static `@JS()` extension-type bindings via `dart:js_interop`.
- **WasmGC Buffer Copies:** In `dart2wasm`, Dart objects live on the WasmGC heap, so calling `.toJS` on a Dart-allocated `Uint8List` **copies** bytes into JS memory. For zero-copy bulk transfers, receive or allocate `JSArrayBuffer` / `JSUint8Array` on the JS side and create a Dart view with `.toDart` (which also unwraps back via `.toJS` without copying).

---

## 5. Pre-Output Verification Checklist

Before finalizing any Flutter code response, verify all 7 gates:
1. **Syntax & Flutter 3.50 APIs:** Dot-shorthands (`.center`, `const .all(...)`), primary constructors (`class const`, `this : super(...)`), null-aware elements (`?child`), switch expressions, `package:material_ui` / `cupertino_ui` (not deprecated `material.dart`), `scrollCacheExtent` (not `cacheExtent`), `Matrix4.*ByDouble` (not `translate`/`scale`), and `.withValues(alpha: ...)` are used—while helper prefixes (`Icons.*`, `Colors.*`) and supertype constructors (`const BoxDecoration(...)`) remain explicit.
2. **Const & Decomposition:** Every eligible constructor, widget, and decoration is `const`; `build()` methods stay flat (< 40 lines) with zero `_build*()` helper methods; single-purpose `Container`s are avoided; `Image` sets `cacheWidth` / `cacheHeight` where appropriate.
3. **Viewport & Rebuild Scope:** High-frequency state is isolated to leaf `ValueListenableBuilder` / `ListenableBuilder` scopes; scrollables use lazy slivers with explicit extent hints (`itemExtent` / `prototypeItem` / `itemExtentBuilder`) and `scrollCacheExtent`; `BackdropGroup` only wraps non-overlapping identical blurs.
4. **Hot-Path Purity & `saveLayer` Avoidance:** Zero mutable allocations (`Paint`, `Path`, `Matrix4`, `TextPainter`, `List`) occur inside `paint()` or `Ticker` callbacks; `CustomPainter` instances are cached in `State`; leaf alpha modulation is preferred over `Opacity` / `OpacityLayer` `saveLayer()` stalls.
5. **Surgical `RepaintBoundary`:** Applied only at true asymmetric repaint seams (never wrapping co-repainting scroll/animated trees, trivial widgets, or redundant `ListView.builder` item roots) and verified with DevTools Highlight Repaints / `RenderRepaintBoundary` metrics.
6. **SIMD, Concurrency & Wasm Readiness:** Compute-intensive numeric loops use `Float32x4List` (`v128` SIMD); native background work uses `Isolate.run` + `TransferableTypedData` while web/Wasm code guards against `dart:isolate` (using Web Workers) and avoids unnecessary Dart-to-JS typed-array copies under `dart2wasm`.
7. **Lifecycle Hygiene:** Every `AnimationController`, `TextEditingController`, `FocusNode`, `ScrollController`, `FragmentShader`, cached `ui.Picture`, JNI reference (`.release()`), and `ValueNotifier` owned by a `State` is explicitly disposed in `dispose()`.
