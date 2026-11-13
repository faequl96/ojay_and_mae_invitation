---
name: flutter-expert
description: Production engineering standard for writing modern, measurable, high-performance Flutter 3.50 and Dart 3.14+ code. Automatically apply when creating, refactoring, optimizing, or reviewing Flutter widgets, slivers, RepaintBoundary placement, state management, CustomPainters, FragmentShaders, 3D Matrix4 projections, SIMD (v128) pipelines, Direct Native Interop (JNIgen/FFIgen/Native Assets), isolates, or WebAssembly (--wasm) builds.
---

# Flutter 3.50 & Dart 3.14+ High-Performance Engineering Standard

Write idiomatic, low-boilerplate, empirically verifiable Flutter 3.50 (Dart 3.14+) code. Every widget tree, layout pass, render layer, and worker boundary must minimize rebuild scope, avoid hot-path allocations and `saveLayer()` stalls, respect platform threading constraints, and be verifiable in **Profile/Release** builds under Impeller (native) and Skwasm (`dart2wasm`).

---

## 1. Modern Dart 3.14+ Syntax & Flutter 3.50 API Hygiene

Separate **syntax/API hygiene** (readability, static safety, deprecation compliance) from **runtime/bundle performance optimizations**—do not conflate clean syntax with measurable frame-time gains:
- **Syntax/Deprecation Hygiene (No Direct Runtime Speedup):** Dot-shorthands (Dart 3.10+), non-`const` primary constructors (Dart 3.13+), null-aware collection elements (Dart 3.8+), `package:material_ui` / `cupertino_ui`, `scrollCacheExtent`, `PopScope<T>`, and `WidgetState`.
- **Direct Compiler/Runtime/Size Impact:** `const` canonicalization, zero-`dynamic` typing (enables AOT Type Flow Analysis devirtualization), unboxed `extension type`s, `Matrix4.*ByDouble` (avoids dynamic/varargs dispatch in deprecated `translate`/`scale`), and choosing `package:flutter/widgets.dart` vs `package:material_ui` when minimizing binary size.

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
      Image.network(
        url,
        width: 128,
        fit: .cover,
        cacheWidth: 128,
        useLogicalCacheSize: true,
      ),
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
- **Typed Records:** Return multiple values via `({double x, double y, double z})` instead of allocating single-use wrapper classes.
- **Exhaustive `switch` Expressions:** Map `sealed` primary constructor hierarchies directly to widgets or values with compile-time exhaustiveness checking.
- **Extension Types:** Wrap primitive domain units (`Radians`, `Milliseconds`, `EntityId`) to enforce static unit safety without allocating an extra wrapper class (omit `implements` when strict unit isolation is desired). **Caveat:** passing an extension type over a primitive (`double`/`int`) as `Object?`, `num`, nullable (`Radians?`), or into unspecialized generics still erases the extension type and boxes the underlying primitive:

```dart
extension type const Radians(double value) {
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
- **Zero `dynamic` Policy:** Never use `dynamic` or unchecked casts. Use `Object?`, constrained generics, `sealed` hierarchies, or typed records so AOT Type Flow Analysis can devirtualize calls.
- **Modern Flutter 3.50 APIs Only:**
  * Use `package:material_ui/material_ui.dart` / `package:cupertino_ui/cupertino_ui.dart` — never deprecated `package:flutter/material.dart` / `package:flutter/cupertino.dart` (deprecated after v3.47.0). For custom design systems where binary/Wasm size matters, prefer `package:flutter/widgets.dart` because `MaterialApp`/`Theme` retains `material_color_utilities` and `*ThemeData` paths during tree-shaking (verify with `--analyze-size`).
  * Use `scrollCacheExtent: const ScrollCacheExtent.pixels(...)` (or `.viewport(...)`) — never deprecated `cacheExtent` / `cacheExtentStyle` (deprecated after v3.41.0).
  * Use `color.withValues(alpha: 0.5)`, `.r`/`.g`/`.b`/`.a`, and `.toARGB32()` — never deprecated `.withOpacity()`, `.value`, or `.red`/`.green`/`.blue`/`.alpha`/`.opacity`.
  * Use `Matrix4.translateByDouble(...)` / `translateByVector3(...)` and `scaleByDouble(...)` / `scaleByVector3(...)` — never deprecated `Matrix4.translate()` / `Matrix4.scale()`.
  * Use `PopScope<T>` and `WidgetStateProperty` / `WidgetState` — never legacy `WillPopScope` or `MaterialStateProperty`.

---

## 2. Widget Tree, Rebuild Isolation & Sliver Virtualization

### A. Granular Reactive Scopes
Never call `setState()` high in a widget tree when only a leaf widget changes. Isolate high-frequency updates (scroll offsets, drag deltas, timers, audio/sensor streams) using `ValueNotifier<T>` + `ValueListenableBuilder<T>` or `ListenableBuilder` (with `Listenable.merge([...])` for multi-source listeners), and always pass static subtrees via the `child:` parameter.

On 120 Hz hot paths, prefer paint/transform updates (`Transform`, `CustomPaint`) over layout-invalidating properties (`FractionallySizedBox.widthFactor`). **Caveat:** `Transform.scale` scales borders, rounded corners, and inner text as well—only use it on uniform fills (`ColoredBox`, unbordered bars) or pair with clipping / `CustomPaint` when visual distortion must be avoided:

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

### B. `const` Canonicalization, Widget Decomposition & Image Decode Sizing
- **`const` Short-Circuiting:** Mark every eligible constructor, widget, `EdgeInsets`, `BoxDecoration`, `BorderRadius`, and `TextStyle` as `const`. When a parent rebuilds, `Element.updateChild` short-circuits in $O(1)$ via `child.widget == newWidget` (`identical(this, other)`), skipping `build()` on unchanged subtrees (note: `InheritedWidget` dependencies inside a `const` widget still trigger `didChangeDependencies()` → `build()` when that inherited data changes).
- **Widget Class Decomposition vs. Helper Methods:** Extract subtrees into private `StatelessWidget` classes (`class const _HeaderSection(...)`) **whenever** the subtree is `const`-eligible, reads `InheritedWidget`s (`Theme.of`, `MediaQuery.of`, providers), or isolates a rebuild scope—because `_buildSection()` helper methods share the parent's `BuildContext` (subscribing the entire parent to inherited changes) and cannot `const`-short-circuit. Conversely, do not force tightly-coupled, non-`const` dynamic leaves into extra `StatelessWidget` classes if they always rebuild with the parent and only add extra `Element` nodes.
- **Avoid Single-Purpose `Container`s:** `Container` is a non-`const` `StatelessWidget` that allocates an extra `StatelessElement` around `Padding`/`ColoredBox`/`DecoratedBox`/`ConstrainedBox`/`Transform`; use `const Padding`, `ColoredBox`, `DecoratedBox`, `SizedBox`, or `Align` directly for single-purpose wrappers.
- **Image Decode Bounds (`cacheWidth` / `cacheHeight`):** Specify decode limits for large local/native photos to avoid storing uncompressed 4K bitmaps in `ImageCache`, with four mandatory rules:
  1. By default (`useLogicalCacheSize: false`), `cacheWidth` / `cacheHeight` expect **physical pixels**, not logical dp—either pass `(logicalSize * MediaQuery.devicePixelRatioOf(context)).round()` or set `useLogicalCacheSize: true` (Flutter 3.50) when passing logical dp.
  2. Usually set **only one** dimension (`cacheWidth` *or* `cacheHeight`) so the decoded image preserves its source aspect ratio instead of stretching.
  3. Avoid varying `cacheWidth` slightly for the same asset across screens—each `(cacheWidth, cacheHeight)` creates a distinct `ResizeImageKey` entry in `ImageCache`.
  4. On **Web** (including `--wasm`), `Image.network` ignores `cacheWidth` / `cacheHeight` because decoding is delegated to the browser; resize/serve appropriately sized assets from your CDN/server.

### C. High-Efficiency Viewports, Slivers & Grouped Blurs
- **Never use `shrinkWrap: true`** on `ListView` or `GridView` inside another scrollable (forces eager $O(N)$ layout of all children). Compose a single `CustomScrollView` with lazy slivers (avoid eagerly building tall multi-section `SingleChildScrollView` + `Column` pages).
- **Sliver Extent Hints:**
  * Prefer `itemExtent` (`SliverFixedExtentList.builder`) or `prototypeItem` (`SliverPrototypeExtentList.builder`) whenever items share a uniform main-axis size: this avoids laying out off-screen/skipped children during scroll jumps and resolves `indexToLayoutOffset` in **$O(1)$**.
  * Use `itemExtentBuilder` (`SliverVariedExtentList.builder`) when heights vary by a cheap formula/lookup: it skips building and laying out skipped child widgets, though offset lookup still loops over `itemExtentBuilder` in **$O(\text{index})$** (prefer `SliverList.builder` only when heights genuinely depend on laid-out content).
- **Grouped Blurs:** When multiple **non-overlapping** glassmorphic widgets share an **identical** unbounded blur configuration (`bounds: null` / `bounded: false`), wrap a stable ancestor in `BackdropGroup` (caching `BackdropKey` in `State` so parent rebuilds do not allocate a new `BackdropKey` and trigger `updateShouldNotify`) and wrap each `BackdropFilter.grouped` in an exact `ClipRect`/`ClipRRect`. Remember that even grouped `BackdropFilter` runs a GPU backdrop pass—profile on low/mid-tier mobile GPUs:

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
At 120 Hz, the total frame budget is **8.33 ms** (16.67 ms at 60 Hz).
- Never instantiate mutable or engine-backed objects (`Paint`, `Path`, `Matrix4`, `Float64List`, `TextPainter`, `PictureRecorder`, `ui.Shader` via `gradient.createShader(rect)`, or temporary `List`s) inside `CustomPainter.paint()`, `RenderBox.paint()`, or animation tick callbacks. Note that `Gradient` itself (`const LinearGradient(...)`) is immutable; it is `gradient.createShader(rect)` that allocates a disposable `ui.Shader` and should be cached until `size` or gradient inputs change.
- Pre-allocate and mutate buffers in place (`_wavePath.reset()`). Cache `late final _painter` in `State` **only** when painter inputs are fixed or driven by `Listenable` (`super(repaint: phase)`)—never share a `CustomPainter` with mutable fields across multiple `CustomPaint` widgets, and update/reconstruct if widget-driven parameters change.
- **Pre-Recording `ui.Picture` vs. Rasterized `ui.Image` under Impeller:** Recording a `ui.Picture` once outside `paint()` and replaying `canvas.drawPicture(picture)` eliminates **Dart CPU `paint()` and `DisplayList` recording overhead**, **not** GPU rasterization (Impeller still rasterizes the recorded `DisplayList` each frame). If a dense static vector layer still bottlenecks the **Raster thread**, benchmark rasterizing it once via `picture.toImageSync(physicalW, physicalH)` (or `toImage`), trading VRAM and fixed pixel resolution for a fast GPU texture blit—and call `.dispose()` on all `Picture`, `Image`, and `Shader` instances in `dispose()`:

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
- Pre-allocate `Matrix4` buffers in `State` or the painter and mutate entries in place (`setIdentity()`, `setEntry(3, 2, perspective)`, `rotateY()`, `translateByDouble(x, y, z, 1.0)`, `scaleByDouble(sx, sy, sz, 1.0)`) rather than chaining allocating constructors per frame.
- Inside `CustomPainter.paint()` when drawing custom cards/sprites directly, pass `_matrix.storage` to `canvas.transform(...)` to avoid `RenderTransform`'s internal `Matrix4.copy(value)` and compositor `TransformLayer` overhead. **Limitation:** if cards contain interactive child widgets (gestures, text selection, accessibility semantics, `PlatformView`s), you still need `Transform` / `RenderTransform`.
- Perform backface culling and $Z$-order depth sorting on lightweight index buffers before building or painting visible items (verify normal $Z$ / screen-space winding sign against your `setEntry(3, 2, ...)` sign convention).

### C. Batch Canvas Primitives, `saveLayer()` Elimination & Surgical `RepaintBoundary`
- **Batch Draw Calls:** Prefer `Canvas.drawRawPoints`, `Canvas.drawRawAtlas`, or `Canvas.drawVertices` (backed by pre-allocated `Float32List` / `Int32List` buffers) over hundreds of individual `drawCircle` / `drawRect` calls.
- **Eliminate `saveLayer()` Stalls:**
  * **Avoid wrapping multi-child / overlapping subtrees in `Opacity`, `AnimatedOpacity`, or `FadeTransition` when leaf alpha works.** `RenderOpacity` and `RenderAnimatedOpacity` push a compositor `OpacityLayer` whenever `_alpha > 0`; at intermediate alpha (`0 < alpha < 255`), multi-primitive/overlapping subtrees defeat the engine's single-primitive opacity peephole optimization and trigger an offscreen `saveLayer()` render pass.
  * **Best:** Modulate alpha directly on leaf primitives (`color.withValues(alpha: a)`, `Image(..., opacity: animation)` on native/canvas targets—note `opacity` is ignored on Web HTML platform views, `TextStyle`, or `Paint.color`).
  * **When fading a composite group is unavoidable:** Prefer `FadeTransition` (explicit `Animation<double>`) or `AnimatedOpacity` over animating `Opacity` via `setState`, because `RenderAnimatedOpacity` updates the `OpacityLayer` directly without widget rebuilds or child repaints—and keep the wrapped subtree as tight/shallow as possible.
  * **Binary Show/Hide:** Use `Visibility(visible: ..., child: ...)` (replaces with `SizedBox.shrink()` when hidden) or `Visibility(visible: ..., maintainState: true, child: ...)` (`Offstage`, non-interactive). If layout space, animations, and state must remain preserved while **blocking touches and focus** when hidden, use `Visibility(visible: ..., maintainState: true, maintainAnimation: true, maintainSize: true, child: ...)`—which already wraps `IgnorePointer` and `ExcludeFocus` internally. Avoid `Visibility.maintain`, because `.maintain` sets `maintainInteractivity: true` and `maintainFocusability: true`.
  * **Avoid `Clip.antiAliasWithSaveLayer`:** Use `Clip.antiAlias` or `BoxDecoration(borderRadius: ...)`.
- **Surgical `RepaintBoundary` (Avoid Layer-Overhead Bottlenecks):**
  * **How it works (Impeller vs. Skia):** `RepaintBoundary` stops `markNeedsPaint()` propagation and isolates `DisplayList` recording (`PictureLayer` / `OffsetLayer`) so static ancestors/siblings don't re-run `paint()` on the UI thread. Unlike legacy Skia, **Impeller removed the persistent `PictureLayer` raster texture cache**—do not add `RepaintBoundary` expecting Impeller to cache static subtrees as persistent offscreen GPU bitmaps.
  * **When to USE (Asymmetric Repaints):** Tightly wrap high-frequency `CustomPaint` canvases, continuous tickers, or localized animations so static siblings don't re-record; or isolate a genuinely heavy static background beneath an independently animating overlay.
  * **When to AVOID:**
    1. **Symmetric / Co-Repainting Subtrees:** Never wrap parent and child when both repaint on the same frames (e.g., scroll-driven parallax sections inside a `SingleChildScrollView`, or multiple widgets driven by the same animation).
    2. **Micro-Boundaries on Cheap Widgets:** Never wrap simple `Text`, `Icon`, or basic `DecoratedBox` widgets—layer-tree traversal and compositing overhead outweigh trivial paint cost.
    3. **Double Boundaries in Lazy Lists:** `ListView.builder`, `GridView.builder`, and `SliverList.builder` wrap each item in `RepaintBoundary` by default (`addRepaintBoundaries: true`). Never add another `RepaintBoundary` at the item root; for ultra-lightweight rows, benchmark `addRepaintBoundaries: false`.
    4. **Misplaced Around `Transform`:** Wrapping `RepaintBoundary` *outside* an animating `Transform` still re-records the `Transform` and child together unless the heavy static child inside `Transform` is itself isolated.
    5. **Non-Paint Jank:** `RepaintBoundary` never fixes `build()` or `layout()` bottlenecks.
  * **Verify Two Ways:** In Debug mode, inspect `debugRepaintRainbowEnabled` and `RenderRepaintBoundary.debugSymmetricPaintCount` vs. `debugAsymmetricPaintCount` via `debugDumpRenderTree()` (always `0` in release); then confirm actual UI/Raster frame-time reduction in **Profile mode** (`--profile`).

### D. Fragment Shaders (`ui.FragmentProgram`)
Load `FragmentProgram.fromAsset('shaders/effect.frag')` **once** during initialization, create and cache the reusable `FragmentShader` via `program.fragmentShader()` (simultaneous callers with distinct uniforms need separate instances), update uniforms (`shader.setFloat(...)` / `shader.setImageSampler(...)`) inside `paint()`, and call `shader.dispose()` in `dispose()`.

---

## 4. SIMD (`v128`), Concurrency, Direct Native Interop & WebAssembly (`--wasm`)

### A. 128-Bit SIMD Acceleration (`Float32x4List`) for Native & WebAssembly
Dart 3.14 (`flutter build web --wasm`) compiles `Float32x4`, `Int32x4`, `Float64x2`, and directly constructed `Float32x4List` / `Int32x4List` / `Float64x2List` (`WasmArray<WasmV128>`) to **WebAssembly 128-bit SIMD (`v128`)** instructions as well as ARM NEON and x86 SSE on native AOT targets. Use 4-lane SIMD vectors for heavy particle physics, 3D vertex projection, layout solvers, and signal processing (DAQ/DSP):

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

**Critical SIMD Guardrails:**
- **Allocate `Float32x4List(n)` directly:** On `dart2wasm`, calling `.buffer.asFloat32x4List()` on a regular `Float32List` or JS-backed `ByteBuffer` falls back to scalar `NaiveFloat32x4List` instead of `WasmArray<WasmV128>`.
- **Avoid scalar-fallback methods in tight loops:** Operations such as `Float32x4.clamp()` extract scalar lanes under `dart2wasm`.
- **`dart2js` fallback awareness:** On browsers without WasmGC where `dart2js` runs, `Float32x4List` has no hardware SIMD and allocates a JS wrapper object per element access—benchmark against plain `Float32List` if non-Wasm web users are a primary target.

### B. Concurrency: Native Isolates, Worker Pools & Web Workers
- **Native Targets (iOS, Android, Desktop):**
  * Use `Isolate.run(...)` only for **coarse-grained / one-off** heavy tasks (large JSON parsing, RSA/AES crypto, image decode, large binary parse) where work substantially exceeds isolate spawn overhead (~1 ms+). Never capture `State`, `BuildContext`, or controllers inside `Isolate.run` closures—use top-level/static functions with sendable arguments.
  * For **high-frequency/per-frame** streams (audio frames, live sensor/DAQ buffers), keep a **long-lived worker `Isolate`** (`Isolate.spawn` + `SendPort`/`ReceivePort`) to avoid repeated spawn/teardown overhead.
  * **`TransferableTypedData` Accuracy:** Creating `TransferableTypedData.fromList([buffer])` takes **$O(N)$ copy time proportional to byte length**; only `SendPort.send()` moves it between isolates in **$O(1)$** (avoiding a second serialization copy), and do not reuse the local transferable after sending. Returning results via `Isolate.exit(port, result)` (used internally by `Isolate.run` upon completion) is true zero-copy from worker to caller.
- **Web & `--wasm` Targets:** `dart:isolate` (`Isolate.run`, `Isolate.spawn`, `TransferableTypedData`) is **unsupported on Web** and throws `UnsupportedError` at runtime. Guard isolate usage behind `kIsWeb` / conditional imports and offload heavy web work to **Web Workers** (via `package:web` + `dart:js_interop` or a worker abstraction) or chunked frame scheduling.

### C. Direct Native Interop (`JNIgen`, `FFIgen`, `@Native` & Native Assets)
Prefer direct native interop over serialized `MethodChannel` round-trips when calling **fast, high-frequency, non-blocking** native APIs:
- **C/C++/Rust (`dart:ffi` on Android, iOS, macOS, Windows, Linux):** Declare bindings with `@Native<NativeSignature>(assetId: ..., isLeaf: true)` bundled via `hook/build.dart` (`package:hooks` + `package:native_toolchain_c`; use `hook/link.dart` + `@RecordUse()` for symbol tree-shaking). Only set `isLeaf: true` when the native function never calls back into Dart or accesses Dart `Handle`s.
- **Android (`jnigen`) & iOS/macOS (`ffigen`):** Call Kotlin/Java and Objective-C/Swift (`@objc`) APIs directly (or via Pigeon with `useJni: true` / `useFfi: true`). Release scoped Android JNI objects with `using((arena) { ... releasedBy(arena); })`, call `.release()` in `dispose()` on long-lived references to stay well below the JNI global reference limit, and preserve reflection/JNI targets with `@Keep` / ProGuard rules in release builds.
- **Threading Guardrail:** Direct `@Native`/FFI/JNI calls execute **synchronously on the calling Dart isolate**. Never invoke slow/blocking OS/IO native calls synchronously from the UI isolate (which causes immediate frame drops); run blocking FFI/JNI inside a worker isolate or use async `MethodChannel`/background platform task queues.

### D. WebAssembly (`--wasm`) Strict Compatibility
Keep all cross-platform and web code 100% compatible with `flutter build web --wasm` (which renders with **Skwasm** on WasmGC-capable browsers; add `--no-deprecated-js-interop` to enforce the same ban on the `dart2js` JS fallback):
- **Strictly Forbidden:** `dart:html`, `dart:js`, `dart:js_util`, `package:js`, and unguarded `dart:io`, `dart:isolate`, or `dart:mirrors`.
- **Required:** `package:web` for DOM/Browser APIs and static `@JS()` extension-type bindings via `dart:js_interop`.
- **WasmGC Buffer Copies vs. Boundary Crossings:** In `dart2wasm`, Dart objects live on the WasmGC heap, so calling `.toJS` on a Dart-allocated `Uint8List` **copies** bytes into JS memory. Receiving a `JSArrayBuffer` / `JSUint8Array` from JS and calling `.toDart` creates a zero-copy view (which also unwraps back via `.toJS` without copying). **Caveat:** every indexed read/write on that JS-backed view crosses the Wasm↔JS boundary, so use zero-copy `.toDart` for pass-through or sparse reads, and copy once into a Dart `Uint8List` before tight byte-processing loops in Dart.

---

## 5. Empirical Measurement Protocol & Pre-Output Verification

### A. Measurement & Profiling Protocol (Required to Claim Gains)
1. **Profile/Release Mode Only:** Never judge frame times, rebuild cost, or allocations in Debug mode; always verify in `--profile` or `--release`.
2. **Isolate UI vs. Raster Bottlenecks First:** Use **Flutter DevTools Frame Chart & Timeline** (or `SchedulerBinding.instance.addTimingsCallback` / `integration_test` `watchPerformance`) to determine whether frame budget overruns occur on the **UI thread** (build/layout/paint) or **Raster thread** (`saveLayer`, blurs, shaders, overdraw).
3. **Verify Specific Mechanisms Empirically:**
   - **Rebuild Scope:** Enable `debugProfileBuildsEnabled` (active in `--profile`) or DevTools **Track Widget Rebuilds** to verify leaf-only rebuilds.
   - **Layout/Paint Isolation:** Use `debugProfileLayoutsEnabled` / `debugProfilePaintsEnabled`, plus Debug-mode `debugRepaintRainbowEnabled`, `RenderRepaintBoundary` symmetry counts, and `debugDisableOpacityLayers` / `debugDisableClipLayers` to confirm `RepaintBoundary` and `saveLayer` assumptions—then re-measure frame timings in `--profile`.
   - **Binary & Wasm Footprint:** Run `flutter build <target> --analyze-size` (especially after adopting `package:material_ui` or `--wasm`) to verify tree-shaking and asset sizes.
   - **Compute / Interop Throughput:** Benchmark `Float32x4List` (including `dart2js` fallback if relevant), `Isolate` pools, and JS-buffer strategies on target hardware before keeping added complexity.

### B. Pre-Output Verification Gates
Before finalizing any Flutter code response, verify all 7 gates:
1. **Modern APIs & Syntax:** Dot-shorthands (keeping `Icons.*`/`Colors.*` and supertype constructors like `const BoxDecoration(...)` explicit), `class const` primary constructors where beneficial, null-aware elements, switch expressions, `package:material_ui`/`cupertino_ui` (or `flutter/widgets.dart`), `scrollCacheExtent`, `Matrix4.*ByDouble`, `.withValues(alpha: ...)`, and zero `dynamic`.
2. **Const & Decomposition:** Eligible constructors, widgets, and decorations are `const`; subtrees that are `const`-eligible, read `InheritedWidget`s, or isolate rebuilds are extracted into private `StatelessWidget` classes rather than `_build*()` methods; single-purpose `Container`s are replaced with `const` primitives; `Image` sets `useLogicalCacheSize: true` (or DPR-scaled `cacheWidth`/`cacheHeight` on native).
3. **Viewport & Rebuild Scope:** High-frequency state lives in leaf `ValueListenableBuilder` / `ListenableBuilder` scopes with `child:` caching; scrollables use lazy slivers with `itemExtent`/`prototypeItem` (or `itemExtentBuilder` when heights vary deterministically) and `scrollCacheExtent`; `BackdropGroup` caches `BackdropKey` and only groups identical non-overlapping unbounded blurs.
4. **Hot-Path Purity & `saveLayer` Avoidance:** Zero mutable or engine allocations (`Paint`, `Path`, `Matrix4`, `TextPainter`, `ui.Shader` via `createShader`, `List`) occur inside `paint()` or `Ticker` callbacks; cached `CustomPainter`s own no stale widget props or shared mutable `Path`s; leaf alpha modulation is preferred over `Opacity`/`OpacityLayer` `saveLayer()` stalls; binary show/hide uses `Visibility` properly (never `.maintain` when hidden interactivity must be blocked).
5. **Surgical `RepaintBoundary`:** Applied only at verified asymmetric repaint seams (never wrapping co-repainting scroll/animated trees, trivial widgets, or redundant `ListView.builder` item roots) and confirmed via both repaint diagnostics and `--profile` frame timings.
6. **SIMD, Concurrency, Interop & Wasm Readiness:** Compute-heavy numeric loops construct `Float32x4List` directly (`v128` SIMD in `dart2wasm`); blocking native calls stay off the UI isolate; native workers use `Isolate.run` (coarse) or pooled `Isolate.spawn` (streaming) without capturing `State`/`BuildContext`; Web/Wasm code guards `dart:isolate`, bans legacy JS libs, and balances zero-copy `JSUint8Array.toDart` against Wasm↔JS boundary costs.
7. **Lifecycle Hygiene:** Every `AnimationController`, `TextEditingController`, `FocusNode`, `ScrollController`, `FragmentShader`, cached `ui.Picture` / `ui.Image` / `ui.Shader`, JNI reference (`.release()`), and `ValueNotifier` owned by a `State` is explicitly disposed in `dispose()`.
