import 'package:flutter/material.dart';

import '../l10n/app_text_extension.dart';
import '../widgets/adaptive_page.dart';
import '../theme/app_design_tokens.dart';

class ReleaseNoteView extends StatelessWidget {
  const ReleaseNoteView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.text( '版本说明', 'Release Notes'))),
      body: AdaptivePage(
        desktopMaxWidth: 800,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [
            _buildHeader(context),
            const SizedBox(height: 32),
            _buildFeatureCategory(
              context,
              title: context.text( '同步引擎与架构', 'Sync Engine & Architecture'),
              icon: Icons.sync_rounded,
              features: [
                _FeatureNode(
                  context.text( '分布式 CRDT 协议', 'Distributed CRDT Protocol'),
                  context.text('基于字段级别的冲突解决基线，确保多端并发修改时的最终一致性。',
                    'Field-first conflict resolution baseline ensuring eventual consistency across multi-node modifications.',
                  ),
                ),
                _FeatureNode(
                  context.text( 'HLC 向量时钟', 'HLC Vector Clocks'),
                  context.text('引入混合同步逻辑时钟（Hybrid Logical Clock），在离线编辑场景下提供确定的事件排序。',
                    'Implementation of Hybrid Logical Clocks to provide deterministic event ordering for offline editing.',
                  ),
                ),
                _FeatureNode(
                  context.text( '保险库分库版本管理', 'Vault-Scoped Versioning'),
                  context.text('针对不同 Vault 独立追踪同步序列，彻底解决多身份切换时的版本号跳动问题。',
                    'Independent sequence tracking per vault to eliminate version jumping during identity switching.',
                  ),
                ),
                _FeatureNode(
                  context.text( '增量差分传输', 'Incremental Diffing'),
                  context.text('仅传输自上次同步以来的变更增量，大幅优化超大账号库下的同步流量消耗。',
                    'High-performance delta transmission ensuring optimal bandwidth usage even in large account libraries.',
                  ),
                ),
                _FeatureNode(
                  context.text( '冲突可视化警告', 'Conflict Resolving Banner'),
                  context.text('自动识别并标记“交错修改”状态，阻止潜在的数据覆盖，保护您的数据安全。',
                    'Visual flagging of interleaved modifications to prevent silent overwrites and ensure data integrity.',
                  ),
                ),
                _FeatureNode(
                  context.text( '全量模板同步', 'Template Synchronization'),
                  context.text('现在支持自定义账号模板的云端同步与多端对齐，确保您的分类体系在所有设备上保持一致。',
                    'Support for synchronizing custom account templates across all devices to maintain a consistent classification system.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            _buildFeatureCategory(
              context,
              title: context.text( '安全与隐私防护', 'Security & Privacy'),
              icon: Icons.shield_outlined,
              features: [
                _FeatureNode(
                  context.text( '端到端加密 (E2EE)', 'End-to-End Encryption'),
                  context.text('所有账号负载在离机前完成加密。服务端仅作为加密块的“哑中转站”，无法窥视明文。',
                    'All account payloads are encrypted on-device. Servers act as dumb relay nodes for opaque blocks.',
                  ),
                ),
                _FeatureNode(
                  context.text( '保险库主密钥系统', 'Vault Master Key'),
                  context.text('基于设备绑定的安全根密钥（VMK），为所有加密操作提供底层信任根。',
                    'Device-bound security root providing the foundational trust for all cryptographic operations.',
                  ),
                ),
                _FeatureNode(
                  context.text( '局部数据脱敏保护', 'Selective Data Masking'),
                  context.text('默认对密码、卡号、邮箱等敏感字段进行掩码处理，有效防范侧视泄密。',
                    'Privacy-by-default masking for sensitive fields to prevent over-the-shoulder data leaks.',
                  ),
                ),
                _FeatureNode(
                  context.text( 'OS 级安全存储集成', 'Secure Storage Integration'),
                  context.text('身份令牌与密钥存储于 iOS Keychain / Android Keystore 等底层的安全区域中。',
                    'Keys and identity tokens are persisted within platform-level secure enclaves.',
                  ),
                ),
                _FeatureNode(
                  context.text( '匿名节点标识', 'Anonymous Node IDs'),
                  context.text('随机生成的 Node ID 与 Vault ID，在同步过程中完全隐匿您的物理身份信息。',
                    'Randomly generated identifiers ensuring your physical identity remains untraceable during sync.',
                  ),
                ),
                _FeatureNode(
                  context.text( '主密码弹性管理', 'Flexible Master Password'),
                  context.text('支持随时修改主密码，并允许在初始“跳过设置”后重新启用密码保护，兼顾便捷与安全。',
                    'Modify your master password anytime or enable protection even after skipping initial setup.',
                  ),
                ),
                _FeatureNode(
                  context.text( '保险库彻底销毁', 'Universal Factory Reset'),
                  context.text('在危险区域提供一键重置功能，彻底擦除本地数据库、身份密钥与偏好设置。',
                    'One-tap factory reset to completely wipe local databases, identity keys, and preferences.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            _buildFeatureCategory(
              context,
              title: context.text( '账号资产管理', 'Account Management'),
              icon: Icons.folder_open_outlined,
              features: [
                _FeatureNode(
                  context.text( '高密度账号中心', 'High-Density Hub'),
                  context.text('专为海量账号设计的极简列表引擎，支持丝滑滚动与即时预览。',
                    'Optimized list engine designed for large collections with contextual preview support.',
                  ),
                ),
                _FeatureNode(
                  context.text( '动态模板引擎', 'Dynamic Templates'),
                  context.text('基础模板调整为网站模板，默认覆盖网站、账号、密码和备注，并保留自定义字段扩展。',
                    'The built-in template now focuses on website credentials while custom fields remain available.',
                  ),
                ),
                _FeatureNode(
                  context.text( '外科手术式编辑器', 'Surgical Editor'),
                  context.text('优化的字段录入流线，集成密码生成器与强度评估，实现快速、安全的账号创建。',
                    'Streamlined editing flow with integrated password generator and strength evaluation.',
                  ),
                ),
                _FeatureNode(
                  context.text( '智能字段操作', 'Smart Field Actions'),
                  context.text('单次点击即可完成账号、密码、网址等字段的复制，大幅缩短工作路径。',
                    'Instant one-tap clipboard actions for usernames, passwords, and custom data fields.',
                  ),
                ),
                _FeatureNode(
                  context.text( '软删除数据回收', 'Soft-Deletion Loop'),
                  context.text('具备冲突感知的删除逻辑，支持在多设备间同步删除状态，并保留恢复余地。',
                    'Conflict-aware deletion logic that synchronizes state across devices with safety buffers.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            _buildFeatureCategory(
              context,
              title: context.text( '设计美学与交互', 'Design & Experience'),
              icon: Icons.auto_awesome_outlined,
              features: [
                _FeatureNode(
                  context.text( '响应式自适应布局', 'Modern Adaptive UI'),
                  context.text('一套代码完美适配 Mobile、平板与高分屏桌面端，提供原生级的交互体验。',
                    'Fluid responsive design scaling from small mobile screens to professional workstations.',
                  ),
                ),
                _FeatureNode(
                  context.text( '实时全局搜索', 'Instant Global Search'),
                  context.text('针对标题、邮箱及模板类别的极速过滤，让搜索不再有等待感。',
                    'Extreme filtering by titles, emails, or categories with zero latency perception.',
                  ),
                ),
                _FeatureNode(
                  context.text( '同步状态指示英雄卡', 'Sync Status Hero'),
                  context.text('实时显示同步诊断信息、服务偏移及最新版本进度，让技术状态透明化。',
                    'Real-time transparency of sync diagnostics, clock drift, and version milestones.',
                  ),
                ),
                _FeatureNode(
                  context.text( '微动效果与视觉语境', 'Micro-Interactions'),
                  context.text('精心调校的悬停反馈、成功动画与过场动效，营造高级感软件氛围。',
                    'Carefully tuned hover effects, success animations, and transitions for a premium feel.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
            ),
            borderRadius: BorderRadius.circular(AppRadii.panel),
          ),
          child: const Icon(Icons.rocket_launch, color: Colors.white, size: 40),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'SecretRoy',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          'Version 1.1.0 "Sync & Security+"',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.text( '重新定义您的数字凭证主权', 'Redefining your digital sovereignty'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCategory(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<_FeatureNode> features,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ...features.map((f) => _buildFeatureItem(context, f)),
      ],
    );
  }

  Widget _buildFeatureItem(BuildContext context, _FeatureNode feature) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(
            AppAlphas.high,
          ),
          borderRadius: BorderRadius.circular(AppRadii.panel),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withAlpha(AppAlphas.medium),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              feature.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              feature.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        children: [
          Divider(
            color: theme.colorScheme.outlineVariant.withAlpha(
              AppAlphas.divider,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.text('由 SecretRoy 核心团队呈献',
              'Presented by SecretRoy Core Team',
            ),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _FeatureNode {
  final String title;
  final String description;
  _FeatureNode(this.title, this.description);
}
