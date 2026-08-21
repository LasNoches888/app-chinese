import '../api/app_settings.dart';
import 'local_llm_service.dart';

/// Which on-device model (if any) backs a chat mode — null for the
/// server-side "Professor", which never runs locally.
LocalModelVariant? localVariantFor(ChatMode mode) => switch (mode) {
  ChatMode.localFriend => LocalModelVariant.friend,
  ChatMode.localTutor => LocalModelVariant.tutor,
  ChatMode.server => null,
};

/// Short display name for a local persona, used to fill the `{name}`
/// placeholder in the templated status strings (personaKnocking,
/// personaReady, etc).
String personaName(AppSettings settings, LocalModelVariant variant) =>
    settings.t(
      variant == LocalModelVariant.friend
          ? 'personaNameFriend'
          : 'personaNameTutor',
    );
