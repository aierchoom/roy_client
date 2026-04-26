import '../models/account_item.dart';
import '../models/account_template.dart';
import '../models/hlc.dart';
import 'package:uuid/uuid.dart';

class ConflictLog {
  final String id;
  final String accountId;
  final String fieldKey; // 'name', 'email', or 'data.xxx'
  final String fieldValue;
  final Hlc hlc;
  final int savedAt;

  ConflictLog({
    String? id,
    required this.accountId,
    required this.fieldKey,
    required this.fieldValue,
    required this.hlc,
    int? savedAt,
  })  : id = id ?? const Uuid().v4(),
        savedAt = savedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'id': id,
        'account_id': accountId,
        'key': fieldKey,
        'value': fieldValue,
        'hlc': hlc.toString(),
        'saved_at': savedAt,
      };

  factory ConflictLog.fromJson(Map<String, dynamic> json) {
    return ConflictLog(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      fieldKey: json['key'] as String,
      fieldValue: json['value'] as String,
      hlc: Hlc.parse(json['hlc'] as String),
      savedAt: json['saved_at'] as int,
    );
  }
}

class MergeResult {
  final AccountItem mergedItem;
  final List<ConflictLog> conflictLogs;

  MergeResult(this.mergedItem, this.conflictLogs);
}

class CrdtMergeEngine {
  /// 单行记录冲突裁决合并入口
  static MergeResult merge(AccountItem local, AccountItem remote) {
    if (local.id != remote.id) {
      throw ArgumentError('Attempted to merge different items.');
    }

    final List<ConflictLog> logs = [];

    // --- 1. 拦截墓碑攻击权 (Tombstone Trumps All) ---
    final localDel = local.deleteHlc;
    final remoteDel = remote.deleteHlc;

    if (localDel != null && remoteDel != null) {
      // 双方都删除了
      if (remoteDel.compareTo(localDel) > 0) {
        return MergeResult(remote.copyWith(syncStatus: SyncStatus.synchronized), []);
      }
      return MergeResult(local, []);
    } else if (remoteDel != null) {
      // 远端删除了，本地没删。检查本地是否有比删除更晚的修改事实
      if (remoteDel.compareTo(_getMaxHlc(local)) > 0) {
        // 远端的删除确切发生了在本地最后一次修改之后 -> 远端删得对，接受墓碑
        return MergeResult(remote.copyWith(syncStatus: SyncStatus.synchronized), logs);
      }
      // 本地在它删除后又改了某内容 -> 本地复活了它，让本地的存续权获胜
    } else if (localDel != null) {
      if (localDel.compareTo(_getMaxHlc(remote)) > 0) {
        // 本地的删除权高于远端的最新修改 -> 坚持本地的删除
        return MergeResult(local, []);
      }
    }

    // --- 2. 字段级穿透合并机制 (LWW MAP) ---
    late final String mergedName;
    late final Hlc mergedNameHlc;
    if (remote.nameHlc.compareTo(local.nameHlc) > 0) {
      mergedName = remote.name;
      mergedNameHlc = remote.nameHlc;
      if (local.name != remote.name) {
        logs.add(ConflictLog(accountId: local.id, fieldKey: 'name', fieldValue: local.name, hlc: local.nameHlc));
      }
    } else {
      mergedName = local.name;
      mergedNameHlc = local.nameHlc;
      if (local.name != remote.name && remote.nameHlc.time > 0) {
        logs.add(ConflictLog(accountId: remote.id, fieldKey: 'name', fieldValue: remote.name, hlc: remote.nameHlc));
      }
    }

    late final String mergedEmail;
    late final Hlc mergedEmailHlc;
    if (remote.emailHlc.compareTo(local.emailHlc) > 0) {
      mergedEmail = remote.email;
      mergedEmailHlc = remote.emailHlc;
      if (local.email != remote.email) {
        logs.add(ConflictLog(accountId: local.id, fieldKey: 'email', fieldValue: local.email, hlc: local.emailHlc));
      }
    } else {
      mergedEmail = local.email;
      mergedEmailHlc = local.emailHlc;
      if (local.email != remote.email && remote.emailHlc.time > 0) {
        logs.add(ConflictLog(accountId: remote.id, fieldKey: 'email', fieldValue: remote.email, hlc: remote.emailHlc));
      }
    }

    final Set<String> allDataKeys = {...local.data.keys, ...remote.data.keys};
    final Map<String, String> mergedData = {};
    final Map<String, Hlc> mergedDataHlc = {};

    for (final key in allDataKeys) {
      final lHlc = local.dataHlc[key] ?? Hlc.zero('local');
      final rHlc = remote.dataHlc[key] ?? Hlc.zero('remote');
      final lVal = local.data[key];
      final rVal = remote.data[key];

      if (rHlc.compareTo(lHlc) > 0) {
        mergedData[key] = rVal!;
        mergedDataHlc[key] = rHlc;
        if (lVal != null && lVal != rVal) {
          logs.add(ConflictLog(accountId: local.id, fieldKey: 'data.$key', fieldValue: lVal, hlc: lHlc));
        }
      } else {
        mergedData[key] = lVal!;
        mergedDataHlc[key] = lHlc;
        if (rVal != null && lVal != rVal && rHlc.time > 0) {
          logs.add(ConflictLog(accountId: remote.id, fieldKey: 'data.$key', fieldValue: rVal, hlc: rHlc));
        }
      }
    }

    // --- 3. 分析收敛状态 ---
    bool isPureFastForward = true;
    if (mergedNameHlc.compareTo(remote.nameHlc) != 0) isPureFastForward = false;
    if (mergedEmailHlc.compareTo(remote.emailHlc) != 0) isPureFastForward = false;
    for (final key in mergedDataHlc.keys) {
      if (mergedDataHlc[key]!.compareTo(remote.dataHlc[key] ?? Hlc.zero('remote')) != 0) {
        isPureFastForward = false;
        break;
      }
    }

    SyncStatus finalStatus;
    if (isPureFastForward) {
      // 本地数据完全被远端覆盖，没有任何自己的主张留存，无需进行二次提交
      finalStatus = SyncStatus.synchronized;
    } else {
      // 双方都有修改，发生了交错合并
      if (local.syncStatus == SyncStatus.pendingPush) {
        // 本地原本就有未提交的修改，现在又合成了远端内容，标记为冲突需人工核对
        finalStatus = SyncStatus.conflict;
      } else {
        // 本地之前是同步的，但因为并发逻辑产生缝合怪，标记为待推送以同步到服务器
        finalStatus = SyncStatus.pendingPush;
      }
    }

    final resultItem = AccountItem(
      id: local.id,
      name: mergedName,
      email: mergedEmail,
      templateId: local.templateId,
      data: mergedData,
      createdAt: local.createdAt,
      nameHlc: mergedNameHlc,
      emailHlc: mergedEmailHlc,
      dataHlc: mergedDataHlc,
      serverVersion: remote.serverVersion, // 必须对齐远端版本号，确保协议一致性
      syncStatus: finalStatus,
      isDeleted: false,
    );

    return MergeResult(resultItem, logs);
  }

  static Hlc _getMaxHlc(AccountItem item) {
    Hlc max = item.nameHlc;
    if (item.emailHlc.compareTo(max) > 0) max = item.emailHlc;
    for (final hlc in item.dataHlc.values) {
      if (hlc.compareTo(max) > 0) max = hlc;
    }
    return max;
  }

  static AccountTemplate mergeTemplate(AccountTemplate local, AccountTemplate remote) {
    if (local.templateId != remote.templateId) {
      throw ArgumentError('Attempted to merge different templates.');
    }

    final localDel = local.deleteHlc;
    final remoteDel = remote.deleteHlc;

    if (localDel != null && remoteDel != null) {
      if (remoteDel.compareTo(localDel) > 0) return remote.copyWith(syncStatus: SyncStatus.synchronized);
      return local;
    } else if (remoteDel != null) {
      if (remoteDel.compareTo(local.hlc ?? Hlc.zero('local')) > 0) {
        return remote.copyWith(syncStatus: SyncStatus.synchronized);
      }
    } else if (localDel != null) {
      if (localDel.compareTo(remote.hlc ?? Hlc.zero('remote')) > 0) {
        return local;
      }
    }

    if ((remote.hlc ?? Hlc.zero('remote')).compareTo(local.hlc ?? Hlc.zero('local')) > 0) {
      return remote.copyWith(syncStatus: SyncStatus.synchronized);
    } else {
      return local;
    }
  }
}
