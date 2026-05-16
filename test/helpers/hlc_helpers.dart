// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:secret_roy/models/hlc.dart';

/// HLC (Hybrid Logical Clock) 构造辅助工具。
///
/// 简化测试中反复手写的 `Hlc(counter, 0, 'node')` 模式，提供语义化命名构造器。
///
/// 用法示例：
/// ```dart
/// hlc.local(10)           // => Hlc(10, 0, 'local')
/// hlc.remote(20)          // => Hlc(20, 0, 'remote')
/// hlc.deviceA(5)          // => Hlc(5, 0, 'device_a')
/// hlc.zero                // => Hlc(0, 0, 'local')
/// hlc.now('device_b')     // => Hlc(当前毫秒时间戳, 0, 'device_b')
/// ```
class hlc {
  hlc._();

  /// 本地节点，counter=0
  static Hlc get zero => Hlc.zero('local');

  /// 本地节点，指定 counter
  static Hlc local(int counter) => Hlc(counter, 0, 'local');

  /// remote 节点，指定 counter
  static Hlc remote(int counter) => Hlc(counter, 0, 'remote');

  /// device_a 节点，指定 counter
  static Hlc deviceA(int counter) => Hlc(counter, 0, 'device_a');

  /// device_b 节点，指定 counter
  static Hlc deviceB(int counter) => Hlc(counter, 0, 'device_b');

  /// 使用当前物理时间戳构造（counter=0）
  static Hlc now(String nodeId) => Hlc.now(nodeId);

  /// 构造冲突场景：两个节点在同一物理时间产生不同 counter
  static List<Hlc> conflictAt(int time) => [
    Hlc(time, 0, 'local'),
    Hlc(time, 1, 'remote'),
  ];
}

/// 批量生成一组递增的 HLC，用于模拟同一设备上的连续操作。
///
/// 用法：
/// ```dart
/// final timestamps = hlcSequence(nodeId: 'local', start: 10, count: 5);
/// // => [Hlc(10,0,'local'), Hlc(11,0,'local'), ..., Hlc(14,0,'local')]
/// ```
List<Hlc> hlcSequence({required String nodeId, required int start, required int count}) {
  return List.generate(count, (i) => Hlc(start + i, 0, nodeId));
}
