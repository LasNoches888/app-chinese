import 'package:thermion_flutter/thermion_flutter.dart';

/// Resolves the object that animation and bone calls have to be made
/// against, which is not the one `loadGltf` hands back.
///
/// thermion draws a distinction between a glTF asset and its instances,
/// and its own API is inconsistent about which one it wants:
///
///   * `addAnimationComponent()` quietly redirects to `instances[0]`
///     when called on a top-level asset
///   * `playGltfAnimation()` does not redirect — it passes the receiver's
///     native handle straight through
///   * `getBones()` / `getBoneNames()` likewise, though the library's own
///     comment elsewhere notes "the native bone APIs require a
///     GltfSceneAssetInstance, not a GltfSceneAsset", and
///     `getInverseBindMatrix()` throws outright if it isn't given one
///
/// So calling `addAnimationComponent()` and then `playGltfAnimation()` on
/// what `loadGltf` returns registers the animator on the instance and
/// then sends "play" to a different native object. Nothing drives the
/// skeleton, the skinning matrices are whatever happens to be in the
/// buffer, and the character renders as torn geometry with its materials
/// intact — intermittently, since it depends on uninitialized memory.
/// That was the mascot's "shredded mesh", and it looked identical in the
/// wardrobe and the lesson circle because both did the same thing.
///
/// Keep the value `loadGltf` returned for `destroyAsset`; use this one for
/// anything touching animation, bones or the pose transform.
Future<ThermionAsset> poseTarget(ThermionAsset asset) async {
  if (asset.isInstance) return asset;
  try {
    return await asset.getInstance(0);
  } catch (_) {
    // An asset with no instances is unexpected, but falling back to it is
    // strictly better than failing to show the mascot at all.
    return asset;
  }
}
