import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

class WindowsUser {
  const WindowsUser({required this.accountName, required this.displayName});

  /// Fully qualified account, e.g. `DOMAIN\jdoe`.
  final String accountName;
  final String displayName;

  String get userName => accountName.split(r'\').last;
}

typedef _GetUserNameExNative = Uint8 Function(
  Int32 nameFormat,
  Pointer<Utf16> buffer,
  Pointer<Uint32> size,
);
typedef _GetUserNameExDart = int Function(
  int nameFormat,
  Pointer<Utf16> buffer,
  Pointer<Uint32> size,
);

/// Identifies the user via the Windows logon token of this process,
/// so no credentials are prompted for or stored.
class WindowsAuth {
  static const _nameSamCompatible = 2;
  static const _nameDisplay = 3;

  static WindowsUser? currentUser() {
    if (!Platform.isWindows) return null;

    final getUserNameEx = DynamicLibrary.open('secur32.dll')
        .lookupFunction<_GetUserNameExNative, _GetUserNameExDart>(
          'GetUserNameExW',
        );

    final account = _query(getUserNameEx, _nameSamCompatible);
    if (account == null || account.isEmpty) return null;

    // NameDisplay is only available for domain/Microsoft accounts.
    final display = _query(getUserNameEx, _nameDisplay);
    return WindowsUser(
      accountName: account,
      displayName: (display == null || display.isEmpty)
          ? account.split(r'\').last
          : display,
    );
  }

  static String? _query(_GetUserNameExDart fn, int format) {
    return using((arena) {
      final size = arena<Uint32>()..value = 0;
      fn(format, nullptr, size);
      if (size.value == 0) return null;

      final buffer = arena<Uint16>(size.value).cast<Utf16>();
      if (fn(format, buffer, size) == 0) return null;
      return buffer.toDartString();
    });
  }
}
