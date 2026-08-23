import '../api/app_settings.dart';
import 'local_llm_service.dart';

/// Which on-device model (if any) backs a chat mode — null for the
/// server-side "Professor", which never runs locally.
LocalModelVariant? localVariantFor(ChatMode mode) => switch (mode) {
  ChatMode.localFriend => LocalModelVariant.friend,
  ChatMode.localTutor => LocalModelVariant.tutor,
  ChatMode.server => null,
};

/// Chat modes not currently offered as a live choice.
///
/// The persona picker shows these as disabled "coming soon" rows, and the
/// chat screen falls back to the same placeholder for anyone whose saved
/// setting still points at one — from before Tutor was paused, or from a
/// server build where Professor never shipped. Friend is the only chat
/// mode this returns false for.
bool isChatModeComingSoon(ChatMode mode) =>
    mode == ChatMode.server || mode == ChatMode.localTutor;

/// Short display name for a local persona, used to fill the `{name}`
/// placeholder in the templated status strings (personaKnocking,
/// personaReady, etc).
String personaName(AppSettings settings, LocalModelVariant variant) =>
    settings.t(
      variant == LocalModelVariant.friend
          ? 'personaNameFriend'
          : 'personaNameTutor',
    );
