import 'dart:math';

import 'package:flutter/foundation.dart';

/// 混合逻辑时钟 (Hybrid Logical Clock)
/// 用于在分布式无强一致性服务器的情况下，为所有记录和字段分配绝对偏序时间戳
@immutable
class Hlc implements Comparable<Hlc> {
  final int time;
  final int counter;
  final String nodeId;

  const Hlc(this.time, this.counter, this.nodeId);

  /// 零原点时钟，用于初始化
  factory Hlc.zero(String nodeId) => Hlc(0, 0, nodeId);

  /// 当前物理时间快照此时钟，计数器归零
  factory Hlc.now(String nodeId) =>
      Hlc(DateTime.now().millisecondsSinceEpoch, 0, nodeId);

  static const String _corruptedNodeId = '__corrupted__';

  /// 从序列化字符串恢复时钟 (支持 nodeId 中含有任意数量的 '-')
  /// 解析失败时返回带有 [_corruptedNodeId] 的零时钟，调用方可通过 [isCorrupted] 检测。
  factory Hlc.parse(String value) {
    int firstHyphen = value.indexOf('-');
    if (firstHyphen == -1) return Hlc.zero(_corruptedNodeId);

    int secondHyphen = value.indexOf('-', firstHyphen + 1);
    if (secondHyphen == -1) return Hlc.zero(_corruptedNodeId);

    try {
      int time = int.parse(value.substring(0, firstHyphen));
      int counter = int.parse(value.substring(firstHyphen + 1, secondHyphen));
      String nodeId = value.substring(secondHyphen + 1);
      return Hlc(time, counter, nodeId);
    } catch (_) {
      return Hlc.zero(_corruptedNodeId);
    }
  }

  bool get isCorrupted => nodeId == _corruptedNodeId;

  @override
  int compareTo(Hlc other) {
    if (time != other.time) return time.compareTo(other.time);
    if (counter != other.counter) return counter.compareTo(other.counter);
    return nodeId.compareTo(other.nodeId);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Hlc &&
          time == other.time &&
          counter == other.counter &&
          nodeId == other.nodeId;

  @override
  int get hashCode => Object.hash(time, counter, nodeId);

  @override
  String toString() => '$time-$counter-$nodeId';
}

/// 客户端全局时钟步进器
class SyncClock {
  Hlc _current;
  final String _nodeId;

  SyncClock(this._nodeId, {Hlc? initialClock})
    : _current = initialClock ?? Hlc.zero(_nodeId);

  Hlc get current => _current;

  /// 本地写入时，拨动时钟并获取最新的盖戳
  Hlc send() {
    int nowTime = DateTime.now().millisecondsSinceEpoch;
    if (nowTime > _current.time) {
      _current = Hlc(nowTime, 0, _nodeId);
    } else {
      _current = Hlc(_current.time, _current.counter + 1, _nodeId);
    }
    return _current;
  }

  /// 接收到远端时钟时，强制自我校准并跨越向未来
  void receive(Hlc remote) {
    int nowTime = DateTime.now().millisecondsSinceEpoch;
    if (nowTime > _current.time && nowTime > remote.time) {
      _current = Hlc(nowTime, 0, _nodeId);
      return;
    }
    if (_current.time == remote.time) {
      _current = Hlc(
        _current.time,
        max(_current.counter, remote.counter) + 1,
        _nodeId,
      );
      return;
    }
    if (_current.time > remote.time) {
      _current = Hlc(_current.time, _current.counter + 1, _nodeId);
      return;
    }
    _current = Hlc(remote.time, remote.counter + 1, _nodeId);
  }
}

/// 同步元数据包裹器 (在最新存储中包裹所有原始 Value)
class SyncValue<T> {
  final T value;
  final Hlc hlc;

  const SyncValue(this.value, this.hlc);

  Map<String, dynamic> toJson() => {'v': value, 'hlc': hlc.toString()};

  /// 适用于泛型的反序列化
  factory SyncValue.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJsonT,
  ) {
    return SyncValue(fromJsonT(json['v']), Hlc.parse(json['hlc'] as String));
  }

  /// 适用于基本类型(String, int, bool)的暴力强转简化接口
  factory SyncValue.fromPrimitiveJson(Map<String, dynamic> json) {
    return SyncValue(json['v'] as T, Hlc.parse(json['hlc'] as String));
  }
}
