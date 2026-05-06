import 'dart:math';

import '../models/hlc.dart';
import '../models/totp_credential.dart';

class TotpCredentialMergeEngine {
  const TotpCredentialMergeEngine._();

  static TotpCredential merge(TotpCredential local, TotpCredential remote) {
    final labelWinsRemote = remote.labelHlc.compareTo(local.labelHlc) > 0;
    final configWinsRemote = remote.configHlc.compareTo(local.configHlc) > 0;
    final linksWinsRemote = remote.linksHlc.compareTo(local.linksHlc) > 0;
    final deleteWinsRemote = _remoteDeleteWins(local, remote);

    return local.copyWith(
      label: labelWinsRemote ? remote.label : local.label,
      config: configWinsRemote ? remote.config : local.config,
      linkedAccountIds: linksWinsRemote
          ? remote.linkedAccountIds
          : local.linkedAccountIds,
      labelHlc: _max(local.labelHlc, remote.labelHlc),
      configHlc: _max(local.configHlc, remote.configHlc),
      linksHlc: _max(local.linksHlc, remote.linksHlc),
      isDeleted: deleteWinsRemote ? remote.isDeleted : local.isDeleted,
      deleteHlc: _maxNullable(local.deleteHlc, remote.deleteHlc),
      serverVersion: max(local.serverVersion, remote.serverVersion),
    );
  }

  static bool _remoteDeleteWins(TotpCredential local, TotpCredential remote) {
    final localDelete = local.deleteHlc;
    final remoteDelete = remote.deleteHlc;
    if (remoteDelete == null) return false;
    if (localDelete == null) return true;
    return remoteDelete.compareTo(localDelete) >= 0;
  }

  static Hlc _max(Hlc left, Hlc right) {
    return right.compareTo(left) > 0 ? right : left;
  }

  static Hlc? _maxNullable(Hlc? left, Hlc? right) {
    if (left == null) return right;
    if (right == null) return left;
    return _max(left, right);
  }
}
