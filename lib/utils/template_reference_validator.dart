import '../models/account_template.dart';

/// Validates template reference graphs to prevent circular dependencies.
///
/// Used by template inheritance (Feature 2), template-scoped account links
/// (Feature 1), and nested sub-forms (Feature 3).
class TemplateReferenceValidator {
  /// Returns `true` if adding [candidateId] as a parent of [selfId] would
  /// create a cycle in the inheritance graph.
  static bool wouldCreateInheritanceCycle({
    required String selfId,
    required String candidateId,
    required Map<String, List<String>> parentGraph,
  }) {
    final visited = <String>{};
    final stack = <String>[candidateId];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (current == selfId) return true;
      if (!visited.add(current)) continue;
      stack.addAll(parentGraph[current] ?? []);
    }
    return false;
  }

  /// Returns a set of template IDs that would cause a cycle if added as
  /// parents of [selfId]. These should be excluded from parent picker UIs.
  static Set<String> findInheritanceCycleCandidates({
    required String selfId,
    required Map<String, List<String>> parentGraph,
  }) {
    final result = <String>{};
    // A self-reference is always a cycle.
    result.add(selfId);
    // Any template that transitively has selfId as an ancestor would cycle.
    for (final templateId in parentGraph.keys) {
      if (templateId == selfId) continue;
      if (_hasAncestor(templateId, selfId, parentGraph)) {
        result.add(templateId);
      }
    }
    return result;
  }

  /// Returns `true` if choosing [candidateId] as the [AccountFieldType.subForm]
  /// target of [selfId] would create recursion (direct or indirect).
  static bool wouldCreateSubFormRecursion({
    required String selfId,
    required String candidateId,
    required Map<String, String?> subFormTargets,
  }) {
    if (candidateId == selfId) return true;
    var current = candidateId;
    final visited = <String>{};
    while (current.isNotEmpty) {
      if (current == selfId) return true;
      if (!visited.add(current)) break; // already visited, stop
      current = subFormTargets[current] ?? '';
    }
    return false;
  }

  /// Returns `true` if [descendantId] is transitively a child of [ancestorId]
  /// in the inheritance graph.
  static bool _hasAncestor(
    String descendantId,
    String ancestorId,
    Map<String, List<String>> parentGraph,
  ) {
    final visited = <String>{};
    final stack = <String>[descendantId];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (current == ancestorId) return true;
      if (!visited.add(current)) continue;
      stack.addAll(parentGraph[current] ?? []);
    }
    return false;
  }

  /// Validates that [field]'s [AccountFieldType.templateRef] target is valid.
  /// Returns null if valid, or an error message string if not.
  static String? validateTemplateRef({
    required AccountField field,
    required String selfTemplateId,
  }) {
    if (field.attributes.type != AccountFieldType.templateRef) return null;
    final targetId = field.attributes.targetTemplateId;
    if (targetId == null || targetId.isEmpty) {
      return 'Template reference field "${field.label}" has no target template selected.';
    }
    if (targetId == selfTemplateId) {
      return 'Template reference field "${field.label}" cannot reference its own template.';
    }
    return null;
  }
}
