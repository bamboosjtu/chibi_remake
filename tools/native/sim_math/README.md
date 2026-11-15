# Deterministic simulation calculation backend

This optional RefCounted GDExtension accelerates the existing GDScript state transitions. It has no scene tree, RNG, command queue, actor allocation, or retained world reference. The ordered unit loop calls a named command port assembled once by the domain composition root; its callbacks delegate to the existing weak, guarded GDScript ports. Navigation path selection and final movement/damage application stay in GDScript. Commands execute in the original actor order, with navigation context refreshed after script commands. Collision queries receive the current world's context only for the duration of a call. The outer context is read-only; its navigation-owned contact memo contains only scalar values and is invalidated with the navigation revision (at most 4,096 scalar contact records). Query objects retain only that navigation's grids, never actors or application services, and are released on revision changes and world disposal. Visibility updates return the same arrays/source records as the script implementation, preserving source order and revision semantics.

The script implementation remains the reference and Linux/CI fallback. `math_kernel.gd` initializes the provider once; `force_script` is a test-only backend selector. Both backends must produce identical snapshots, not merely similar checksums or approximate results. Keep the GDScript and C++ algorithms in sync.

## Build

```powershell
python tools/native/sim_math/build.py
python tools/native/sim_math/build.py --check
node tools/rules_manifest.mjs --write
node tools/runtime_assets.mjs --write
```

The build requires MSVC 2019 x64 and CMake. Release builds enable link-time optimization across the module and binding library, retaining `/fp:precise`; no fast-math option is used. `dependency-lock.json` pins the same godot-cpp commit already used by the AVI extension and the official archive's SHA-256. Existing cached dependency files are checked against the pinned archive; modified or additional source files fail. Generated bindings and compiler output stay under `_work/sim-math/`. No original game binary or media is an input.

`native_math.json` records the normalized C++ source hash, embedded in the DLL. A mismatched source/binary pair is rejected by the loader. The runtime asset manifest separately pins the DLL bytes. No signatures, attestation, or certificate service is used. The Godot C++ MIT notice is distributed with the extension.

## Validation

- `test_native_math.gd`: 2,000 seeded fixtures and 16,000 attack updates, queue/status expiry, locomotion, exact persistent-field comparison; 160 seeded full-visibility comparisons including source removal, buildings/sites, death, passengers, overlap and full reveal.
- `test_native_geometry.gd`: contact/occupancy against the script oracle, ordered separation choices, map edges and multiple footprints. Distant separation candidates still require the original GDScript navigation check.
- `test_native_world.gd`: 660 mobile units, six complete-state comparisons between forced script and native execution, including world restore. Benchmark-only HP overrides are reapplied equally after restore because canonical restoration normalizes maximum HP.
- Release suite, unchanged 15/60-second baselines, and real release-PCK performance tests remain required. Headless diagnostic timing is not FPS acceptance evidence.

API setup follows the [official Godot GDExtension C++ interface](https://docs.godotengine.org/en/stable/tutorials/scripting/cpp/gdextension_cpp_example.html). The actual bindings are pinned, not fetched from a floating branch.


The pinned bindings have an unsafe `Dictionary` rvalue assignment implementation. This module deliberately uses a const lvalue when replacing a live dictionary, including navigation contexts; do not replace those assignments with temporaries. The geometry lifetime test and verbose release-pack exit check cover query/grid release. Disposing a world also breaks actor dictionary reference cycles. No third-party source is patched or silently replaced.

The global math provider is released at application exit. Native command ports are disconnected before world services; candidates and active scenes use the same connection code. Native-world differential tests require the batched port to be connected and prove that it actually executes.
