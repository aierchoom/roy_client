import 'dart:convert';
import 'dart:math';

import '../models/account_item.dart';
import '../models/account_template.dart';
import '../models/hlc.dart';
import '../models/template_conflict_log.dart';
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
  }) : id = id ?? const Uuid().v4(),
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

class TemplateMergeResult {
  final AccountTemplate template;
  final List<TemplateConflictLog> conflictLogs;

  TemplateMergeResult(this.template, this.conflictLogs);
}

class CrdtMergeEngine {
  /// 单行记录冲突裁决合并入口
  static MergeResult merge(AccountItem local, AccountItem remote) {
    if (local.id != remote.id) {
      throw ArgumentError('Attempted to merge different items.');
    }

    // If remote HLCs are corrupted, local wins unconditionally to prevent
    // a zero-timestamp HLC from always losing LWW comparisons.
    final _remoteCorrupted = remote.nameHlc.isCorrupted ||
        remote.emailHlc.isCorrupted ||
        remote.dataHlc.values.any((h) => h.isCorrupted);
    if (_remoteCorrupted) {
      return MergeResult(
        local.copyWith(
          syncStatus: SyncStatus.pendingPush,
          serverVersion: max(local.serverVersion, remote.serverVersion),
        ),
        [
          ConflictLog(
            accountId: local.id,
            fieldKey: 'hlc.corrupted_remote',
            fieldValue: 'Remote item had corrupted HLC timestamps; local version preserved.',
            hlc: local.nameHlc,
          ),
        ],
      );
    }

    final List<ConflictLog> logs = [];

    // --- 1. 拦截墓碑攻击权 (Tombstone Trumps All) ---
    final localDel = local.deleteHlc;
    final remoteDel = remote.deleteHlc;

    final int unifiedServerVersion = max(
      local.serverVersion,
      remote.serverVersion,
    );

    if (localDel != null && remoteDel != null) {
      // 双方都删除了
      if (remoteDel.compareTo(localDel) > 0) {
        return MergeResult(
          remote.copyWith(
            syncStatus: SyncStatus.synchronized,
            serverVersion: unifiedServerVersion,
          ),
          [],
        );
      }
      return MergeResult(
        local.copyWith(serverVersion: unifiedServerVersion),
        [],
      );
    } else if (remoteDel != null) {
      // 远端删除了，本地没删。检查本地是否有比删除更晚的修改事实
      if (remoteDel.compareTo(_getMaxHlc(local)) > 0) {
        // 远端的删除确切发生了在本地最后一次修改之后 -> 远端删得对，接受墓碑
        return MergeResult(
          remote.copyWith(
            syncStatus: SyncStatus.synchronized,
            serverVersion: unifiedServerVersion,
          ),
          logs,
        );
      }
      // 本地在它删除后又改了某内容 -> 本地复活了它，让本地的存续权获胜
    } else if (localDel != null) {
      if (localDel.compareTo(_getMaxHlc(remote)) > 0) {
        // 本地的删除权高于远端的最新修改 -> 坚持本地的删除
        return MergeResult(
          local.copyWith(serverVersion: unifiedServerVersion),
          [],
        );
      }
    }

    // --- 2. 字段级穿透合并机制 (LWW MAP) ---
    late final String mergedName;
    late final Hlc mergedNameHlc;
    if (remote.nameHlc.compareTo(local.nameHlc) > 0) {
      mergedName = remote.name;
      mergedNameHlc = remote.nameHlc;
      if (local.name != remote.name) {
        logs.add(
          ConflictLog(
            accountId: local.id,
            fieldKey: 'name',
            fieldValue: local.name,
            hlc: local.nameHlc,
          ),
        );
      }
    } else {
      mergedName = local.name;
      mergedNameHlc = local.nameHlc;
      if (local.name != remote.name && remote.nameHlc.time > 0) {
        logs.add(
          ConflictLog(
            accountId: remote.id,
            fieldKey: 'name',
            fieldValue: remote.name,
            hlc: remote.nameHlc,
          ),
        );
      }
    }

    late final String mergedEmail;
    late final Hlc mergedEmailHlc;
    if (remote.emailHlc.compareTo(local.emailHlc) > 0) {
      mergedEmail = remote.email;
      mergedEmailHlc = remote.emailHlc;
      if (local.email != remote.email) {
        logs.add(
          ConflictLog(
            accountId: local.id,
            fieldKey: 'email',
            fieldValue: local.email,
            hlc: local.emailHlc,
          ),
        );
      }
    } else {
      mergedEmail = local.email;
      mergedEmailHlc = local.emailHlc;
      if (local.email != remote.email && remote.emailHlc.time > 0) {
        logs.add(
          ConflictLog(
            accountId: remote.id,
            fieldKey: 'email',
            fieldValue: remote.email,
            hlc: remote.emailHlc,
          ),
        );
      }
    }

    final Set<String> allDataKeys = {
      ...local.data.keys,
      ...remote.data.keys,
      ...local.dataHlc.keys,
      ...remote.dataHlc.keys,
    };
    final Map<String, dynamic> mergedData = {};
    final Map<String, Hlc> mergedDataHlc = {};

    for (final key in allDataKeys) {
      final lHlc = local.dataHlc[key] ?? Hlc.zero('local');
      final rHlc = remote.dataHlc[key] ?? Hlc.zero('remote');
      final lVal = local.data[key];
      final rVal = remote.data[key];

      if (rHlc.compareTo(lHlc) > 0) {
        // Remote wins: keep value only if present (null means remote deleted)
        if (rVal != null) {
          mergedData[key] = rVal;
        }
        mergedDataHlc[key] = rHlc;
        if (lVal != null && lVal != rVal) {
          logs.add(
            ConflictLog(
              accountId: local.id,
              fieldKey: 'data.$key',
              fieldValue: lVal.toString(),
              hlc: lHlc,
            ),
          );
        }
      } else {
        // Local wins: keep value only if present (null means local deleted)
        if (lVal != null) {
          mergedData[key] = lVal;
        }
        mergedDataHlc[key] = lHlc;
        if (rVal != null && lVal != rVal && rHlc.time > 0) {
          logs.add(
            ConflictLog(
              accountId: remote.id,
              fieldKey: 'data.$key',
              fieldValue: rVal.toString(),
              hlc: rHlc,
            ),
          );
        }
      }
    }

    // --- 3. 分析收敛状态 ---
    bool isPureFastForward = true;
    if (mergedNameHlc.compareTo(remote.nameHlc) != 0) {
      isPureFastForward = false;
    }
    if (mergedEmailHlc.compareTo(remote.emailHlc) != 0) {
      isPureFastForward = false;
    }
    for (final key in mergedDataHlc.keys) {
      if (mergedDataHlc[key]!.compareTo(
            remote.dataHlc[key] ?? Hlc.zero('remote'),
          ) !=
          0) {
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
      serverVersion: unifiedServerVersion, // 统一取最大版本号，避免 Tombstone 后 push 409
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

  static TemplateMergeResult mergeTemplate(
    AccountTemplate local,
    AccountTemplate remote,
  ) {
    if (local.templateId != remote.templateId) {
      throw ArgumentError('Attempted to merge different templates.');
    }

    // If remote HLC is corrupted, local wins unconditionally.
    final _remoteTopHlc = remote.hlc ?? Hlc.zero('remote');
    if (_remoteTopHlc.isCorrupted) {
      return TemplateMergeResult(
        local.copyWith(
          syncStatus: SyncStatus.pendingPush,
          serverVersion: max(local.serverVersion, remote.serverVersion),
        ),
        [
          TemplateConflictLog(
            templateId: local.templateId,
            fieldKey: 'hlc',
            attributeName: 'corrupted_remote',
            localValue: local.hlc?.toString() ?? '',
            remoteValue: _remoteTopHlc.toString(),
            localHlc: local.hlc ?? Hlc.zero('local'),
            remoteHlc: _remoteTopHlc,
          ),
        ],
      );
    }

    if (_sameTemplatePayload(local, remote)) {
      return TemplateMergeResult(
        remote.copyWith(
          serverVersion: local.serverVersion > remote.serverVersion
              ? local.serverVersion
              : remote.serverVersion,
        ),
        [],
      );
    }

    final localDel = local.deleteHlc;
    final remoteDel = remote.deleteHlc;
    final int unifiedServerVersion = max(
      local.serverVersion,
      remote.serverVersion,
    );

    if (localDel != null && remoteDel != null) {
      if (remoteDel.compareTo(localDel) > 0) {
        return TemplateMergeResult(
          remote.copyWith(
            syncStatus: SyncStatus.synchronized,
            serverVersion: unifiedServerVersion,
          ),
          [],
        );
      }
      return TemplateMergeResult(
        local.copyWith(
          serverVersion: unifiedServerVersion,
          syncStatus: SyncStatus.synchronized,
        ),
        [],
      );
    } else if (remoteDel != null) {
      if (remoteDel.compareTo(local.hlc ?? Hlc.zero('local')) > 0) {
        return TemplateMergeResult(
          remote.copyWith(
            syncStatus: SyncStatus.synchronized,
            serverVersion: unifiedServerVersion,
          ),
          [],
        );
      }
      return TemplateMergeResult(
        local.copyWith(serverVersion: unifiedServerVersion),
        [],
      );
    } else if (localDel != null) {
      if (localDel.compareTo(remote.hlc ?? Hlc.zero('remote')) > 0) {
        return TemplateMergeResult(
          local.copyWith(
            serverVersion: unifiedServerVersion,
            syncStatus: SyncStatus.synchronized,
          ),
          [],
        );
      }
      return TemplateMergeResult(
        remote.copyWith(serverVersion: unifiedServerVersion),
        [],
      );
    }

    final localHlc = local.hlc ?? Hlc.zero('local');
    final remoteHlc = remote.hlc ?? Hlc.zero('remote');
    final bool remoteWinsTopLevel = remoteHlc.compareTo(localHlc) > 0;

    final String mergedTitle = remoteWinsTopLevel ? remote.title : local.title;
    final String mergedSubTitle = remoteWinsTopLevel
        ? remote.subTitle
        : local.subTitle;
    final int? mergedIconCodePoint = remoteWinsTopLevel
        ? remote.iconCodePoint
        : local.iconCodePoint;
    final TemplateCategory mergedCategory = remoteWinsTopLevel
        ? remote.category
        : local.category;
    final Hlc mergedHlc = remoteWinsTopLevel ? remoteHlc : localHlc;

    final localFields = local.fields;
    final remoteFields = remote.fields;
    final allFieldKeys = {
      ...localFields.map((f) => f.fieldKey),
      ...remoteFields.map((f) => f.fieldKey),
    };

    final List<AccountField> resolvedFields = [];
    final List<TemplateConflictLog> logs = [];

    for (final key in allFieldKeys) {
      final localField = localFields.cast<AccountField?>().firstWhere(
        (f) => f?.fieldKey == key,
        orElse: () => null,
      );
      final remoteField = remoteFields.cast<AccountField?>().firstWhere(
        (f) => f?.fieldKey == key,
        orElse: () => null,
      );

      // Label
      final lLabel = localField?.label ?? '';
      final rLabel = remoteField?.label ?? '';
      final lLabelHlc = localField?.labelHlc ?? Hlc.zero('local');
      final rLabelHlc = remoteField?.labelHlc ?? Hlc.zero('remote');
      final String mergedLabel;
      final Hlc mergedLabelHlc;
      if (rLabelHlc.compareTo(lLabelHlc) > 0) {
        mergedLabel = rLabel;
        mergedLabelHlc = rLabelHlc;
        if (localField != null && lLabel != rLabel) {
          logs.add(
            TemplateConflictLog(
              templateId: local.templateId,
              fieldKey: key,
              attributeName: 'label',
              localValue: lLabel,
              remoteValue: rLabel,
              localHlc: lLabelHlc,
              remoteHlc: rLabelHlc,
            ),
          );
        }
      } else {
        mergedLabel = lLabel;
        mergedLabelHlc = lLabelHlc;
        if (remoteField != null && rLabel != lLabel && rLabelHlc.time > 0) {
          logs.add(
            TemplateConflictLog(
              templateId: remote.templateId,
              fieldKey: key,
              attributeName: 'label',
              localValue: lLabel,
              remoteValue: rLabel,
              localHlc: lLabelHlc,
              remoteHlc: rLabelHlc,
            ),
          );
        }
      }

      // Description
      final lDesc = localField?.description;
      final rDesc = remoteField?.description;
      final lDescStr = lDesc ?? '';
      final rDescStr = rDesc ?? '';
      final lDescHlc = localField?.descriptionHlc ?? Hlc.zero('local');
      final rDescHlc = remoteField?.descriptionHlc ?? Hlc.zero('remote');
      final String? mergedDescription;
      final Hlc mergedDescriptionHlc;
      if (rDescHlc.compareTo(lDescHlc) > 0) {
        mergedDescription = rDesc;
        mergedDescriptionHlc = rDescHlc;
        if (localField != null && lDescStr != rDescStr) {
          logs.add(
            TemplateConflictLog(
              templateId: local.templateId,
              fieldKey: key,
              attributeName: 'description',
              localValue: lDescStr,
              remoteValue: rDescStr,
              localHlc: lDescHlc,
              remoteHlc: rDescHlc,
            ),
          );
        }
      } else {
        mergedDescription = lDesc;
        mergedDescriptionHlc = lDescHlc;
        if (remoteField != null && rDescStr != lDescStr && rDescHlc.time > 0) {
          logs.add(
            TemplateConflictLog(
              templateId: remote.templateId,
              fieldKey: key,
              attributeName: 'description',
              localValue: lDescStr,
              remoteValue: rDescStr,
              localHlc: lDescHlc,
              remoteHlc: rDescHlc,
            ),
          );
        }
      }

      // Attributes
      final lAttr = localField?.attributes;
      final rAttr = remoteField?.attributes;
      final lAttrHlc = localField?.attributesHlc ?? Hlc.zero('local');
      final rAttrHlc = remoteField?.attributesHlc ?? Hlc.zero('remote');
      final AccountFieldAttributes mergedAttributes;
      final Hlc mergedAttributesHlc;
      if (rAttrHlc.compareTo(lAttrHlc) > 0) {
        mergedAttributes =
            rAttr ?? const AccountFieldAttributes(type: AccountFieldType.text);
        mergedAttributesHlc = rAttrHlc;
        if (localField != null &&
            lAttr != null &&
            jsonEncode(lAttr.toJson()) != jsonEncode(rAttr?.toJson())) {
          logs.add(
            TemplateConflictLog(
              templateId: local.templateId,
              fieldKey: key,
              attributeName: 'attributes',
              localValue: jsonEncode(lAttr.toJson()),
              remoteValue: jsonEncode(rAttr?.toJson()),
              localHlc: lAttrHlc,
              remoteHlc: rAttrHlc,
            ),
          );
        }
      } else {
        mergedAttributes =
            lAttr ?? const AccountFieldAttributes(type: AccountFieldType.text);
        mergedAttributesHlc = lAttrHlc;
        if (remoteField != null &&
            rAttr != null &&
            jsonEncode(rAttr.toJson()) != jsonEncode(lAttr?.toJson()) &&
            rAttrHlc.time > 0) {
          logs.add(
            TemplateConflictLog(
              templateId: remote.templateId,
              fieldKey: key,
              attributeName: 'attributes',
              localValue: jsonEncode(lAttr?.toJson()),
              remoteValue: jsonEncode(rAttr.toJson()),
              localHlc: lAttrHlc,
              remoteHlc: rAttrHlc,
            ),
          );
        }
      }

      // Order
      final lOrder = localField?.order ?? 0;
      final rOrder = remoteField?.order ?? 0;
      final lOrderHlc = localField?.orderHlc ?? Hlc.zero('local');
      final rOrderHlc = remoteField?.orderHlc ?? Hlc.zero('remote');
      final int mergedOrder;
      final Hlc mergedOrderHlc;
      if (rOrderHlc.compareTo(lOrderHlc) > 0) {
        mergedOrder = rOrder;
        mergedOrderHlc = rOrderHlc;
        if (localField != null && lOrder != rOrder) {
          logs.add(
            TemplateConflictLog(
              templateId: local.templateId,
              fieldKey: key,
              attributeName: 'order',
              localValue: lOrder.toString(),
              remoteValue: rOrder.toString(),
              localHlc: lOrderHlc,
              remoteHlc: rOrderHlc,
            ),
          );
        }
      } else {
        mergedOrder = lOrder;
        mergedOrderHlc = lOrderHlc;
        if (remoteField != null && rOrder != lOrder && rOrderHlc.time > 0) {
          logs.add(
            TemplateConflictLog(
              templateId: remote.templateId,
              fieldKey: key,
              attributeName: 'order',
              localValue: lOrder.toString(),
              remoteValue: rOrder.toString(),
              localHlc: lOrderHlc,
              remoteHlc: rOrderHlc,
            ),
          );
        }
      }

      resolvedFields.add(
        AccountField(
          fieldKey: key,
          label: mergedLabel,
          description: mergedDescription,
          attributes: mergedAttributes,
          order: mergedOrder,
          labelHlc: mergedLabelHlc,
          descriptionHlc: mergedDescriptionHlc,
          attributesHlc: mergedAttributesHlc,
          orderHlc: mergedOrderHlc,
        ),
      );
    }

    resolvedFields.sort((a, b) => a.order.compareTo(b.order));

    bool isPureFastForward = remoteWinsTopLevel;
    if (isPureFastForward) {
      for (final field in resolvedFields) {
        final remoteField = remoteFields.cast<AccountField?>().firstWhere(
          (f) => f?.fieldKey == field.fieldKey,
          orElse: () => null,
        );
        if (remoteField == null) {
          isPureFastForward = false;
          break;
        }
        if (field.labelHlc.compareTo(remoteField.labelHlc) != 0 ||
            field.descriptionHlc.compareTo(remoteField.descriptionHlc) != 0 ||
            field.attributesHlc.compareTo(remoteField.attributesHlc) != 0 ||
            field.orderHlc.compareTo(remoteField.orderHlc) != 0) {
          isPureFastForward = false;
          break;
        }
      }
    }

    final SyncStatus finalStatus;
    if (isPureFastForward) {
      finalStatus = SyncStatus.synchronized;
    } else {
      if (local.syncStatus == SyncStatus.pendingPush) {
        finalStatus = SyncStatus.conflict;
      } else {
        finalStatus = SyncStatus.pendingPush;
      }
    }

    return TemplateMergeResult(
      AccountTemplate(
        templateId: local.templateId,
        version: remoteWinsTopLevel ? remote.version : local.version,
        title: mergedTitle,
        subTitle: mergedSubTitle,
        iconCodePoint: mergedIconCodePoint,
        category: mergedCategory,
        fields: resolvedFields,
        isCustom: local.isCustom,
        syncStatus: finalStatus,
        hlc: mergedHlc,
        serverVersion: unifiedServerVersion,
        isDeleted: false,
        deleteHlc: null,
      ),
      logs,
    );
  }

  static bool _sameTemplatePayload(
    AccountTemplate local,
    AccountTemplate remote,
  ) {
    final localJson = Map<String, dynamic>.from(local.toJson())
      ..remove('serverVersion')
      ..remove('syncStatus');
    final remoteJson = Map<String, dynamic>.from(remote.toJson())
      ..remove('serverVersion')
      ..remove('syncStatus');
    return jsonEncode(localJson) == jsonEncode(remoteJson);
  }
}
