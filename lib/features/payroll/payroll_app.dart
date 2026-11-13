import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../application/payroll_controller.dart';
import '../../data/city_catalog.dart';
import '../../data/payroll_store.dart';
import '../../domain/payroll_models.dart';
import '../calculator/methodology_screen.dart';
import 'contributions_screen.dart';
import 'payroll_results_screen.dart';
import 'plans_screen.dart';
import 'payroll_widgets.dart';
import 'payroll_share.dart';

class PayrollBootstrap extends StatefulWidget {
  const PayrollBootstrap({
    super.key,
    required this.appBuilder,
    this.controllerLoader,
  });
  final Widget Function(Widget home) appBuilder;
  // Injection point returns an initialized controller; normal startup below
  // owns SQLite/catalog loading and migration.
  final Future<PayrollController> Function()? controllerLoader;
  @override
  State<PayrollBootstrap> createState() => _PayrollBootstrapState();
}

class _PayrollBootstrapState extends State<PayrollBootstrap> {
  PayrollController? controller;
  late Future<void> startup = _start();
  Future<void> _start() async {
    if (widget.controllerLoader != null) {
      controller = await widget.controllerLoader!();
      return;
    }
    final catalog = await CityCatalog.load();
    final store = await PayrollStore.open();
    final prefs = await SharedPreferences.getInstance();
    controller?.dispose();
    controller = PayrollController(
      store: store,
      catalog: catalog,
      prefs: prefs,
    );
    await controller!.initialize();
  }

  @override
  void dispose() {
    // Once provided, ChangeNotifierProvider owns the controller's lifetime.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: startup,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return widget.appBuilder(
          const Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      }
      if (snapshot.hasError) {
        return widget.appBuilder(
          Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('薪酬测算')),
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.folder_off_outlined,
                      size: 48,
                      color: payrollMuted,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '本地数据暂未读取成功',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('原数据不会被默认北京参数覆盖。请重试；如选择新建，原始数据仍保留供恢复。'),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => setState(() => startup = _start()),
                      child: const Text('重试读取'),
                    ),
                    if (controller != null)
                      TextButton(
                        onPressed: () async {
                          if (await confirmAction(
                                context,
                                '保留备份并新建？',
                                '创建默认北京的空白方案，不删除原始备份与历史。',
                              ) &&
                              mounted) {
                            setState(
                              () =>
                                  startup = controller!.recoverWithFreshDraft(),
                            );
                          }
                        },
                        child: const Text('保留备份并新建空白方案'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return ProviderScope(
        overrides: [
          payrollControllerProvider.overrideWith((ref) => controller!),
        ],
        child: widget.appBuilder(const PayrollWorkspace()),
      );
    },
  );
}

class PayrollWorkspace extends ConsumerStatefulWidget {
  const PayrollWorkspace({super.key});
  @override
  ConsumerState<PayrollWorkspace> createState() => _PayrollWorkspaceState();
}

class _PayrollWorkspaceState extends ConsumerState<PayrollWorkspace>
    with WidgetsBindingObserver {
  int tab = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      ref.read(payrollControllerProvider).flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(payrollControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(['薪酬测算', '我的方案', '工具与设置'][tab]),
        actions: [
          if (tab == 0)
            IconButton(
              tooltip: '新建空白方案',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () async {
                if (await confirmAction(
                  context,
                  '新建空白方案？',
                  '当前编辑将替换为默认北京的空白方案，已保存的方案不受影响。',
                )) {
                  c.newBlank();
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (c.persistenceError != null)
            MaterialBanner(
              content: Text(c.persistenceError!),
              actions: [
                TextButton(onPressed: c.retrySave, child: const Text('重试保存')),
              ],
            ),
          Expanded(
            child: IndexedStack(
              index: tab,
              children: [
                const _CalculatorHome(),
                PlansScreen(onCopy: () => setState(() => tab = 0)),
                _ToolsScreen(onHome: () => setState(() => tab = 0)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (tab == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: FilledButton.icon(
                key: const Key('calculate'),
                style: FilledButton.styleFrom(
                  backgroundColor: payrollBlue,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text(
                  '开始测算',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  try {
                    final results = c.calculate();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PayrollResultsScreen(results: results),
                      ),
                    );
                  } catch (e) {
                    showMessage(context, e.toString());
                  }
                },
              ),
            ),
          NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.calculate_outlined),
                selectedIcon: Icon(Icons.calculate),
                label: '测算',
              ),
              NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder),
                label: '方案',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: '工具',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalculatorHome extends ConsumerWidget {
  const _CalculatorHome();
  Future<void> _city(BuildContext context, PayrollController c) async {
    final old = c.draft;
    final chosen = await Navigator.push<CityReference>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CityPicker(catalog: c.catalog, current: c.draft.city.id),
      ),
    );
    if (chosen == null || chosen.id == old.city.id) return;
    c.switchCity(chosen);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已带入${chosen.name}参考参数'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () {
              if (c.draft.id == old.id && c.draft.city.id == chosen.id) {
                c.restoreContributions(old);
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> _settings(BuildContext context, PayrollController c) async {
    final next = await Navigator.push<PayrollDraft>(
      context,
      MaterialPageRoute(builder: (_) => ContributionsScreen(initial: c.draft)),
    );
    if (next != null) c.update(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(payrollControllerProvider), d = c.draft;
    final hf = d.effectiveItems.firstWhere((e) => e.kind == 'hf');
    final years = {2024, 2025, 2026, 2027, DateTime.now().year, d.year}.toList()
      ..sort();
    return ListView(
      key: PageStorageKey('calculator-home-${d.id}'),
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
      children: [
        const Text(
          '算清每月到账',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: payrollInk,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '工资、奖金与五险一金，一份方案看清楚。',
          style: TextStyle(color: payrollMuted),
        ),
        const SizedBox(height: 22),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.location_on_outlined, size: 18),
                    label: Text('${d.city.name} ▾'),
                    onPressed: () => _city(context, c),
                  ),
                  DropdownButton<int>(
                    value: d.year,
                    underline: const SizedBox.shrink(),
                    items: years
                        .map(
                          (y) =>
                              DropdownMenuItem(value: y, child: Text('$y 年')),
                        )
                        .toList(),
                    onChanged: (y) {
                      if (y != null) c.switchYear(y);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AmountField(
                key: ValueKey('${d.id}-salary'),
                label: '税前月薪',
                value: d.salary,
                hint: '请输入你的月薪',
                onChanged: (v) => c.update(c.draft.copyWith(salary: v)),
              ),
              const SizedBox(height: 10),
              const Text(
                '全年同一单位 · 固定月薪 · 12 个月',
                style: TextStyle(fontSize: 12, color: payrollMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: '五险一金',
          trailing: TextButton(
            onPressed: () => _settings(context, c),
            child: const Text('调整 ›'),
          ),
          child: Column(
            children: [
              MetricRow(
                '社保参考基数',
                d.socialBase.isEmpty ? '用当前月薪估算' : '${d.socialBase} 元',
              ),
              MetricRow(
                '公积金参考基数',
                d.housingBase.isEmpty ? '跟随社保参考基数' : '${d.housingBase} 元',
              ),
              MetricRow(
                '公积金个人 / 单位',
                '${rateText(hf.employeeRate)} / ${rateText(hf.employerRate)}',
              ),
              if (d.overrides.isNotEmpty)
                MetricRow('我的调整', '${d.overrides.length} 项', emphasis: true),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () async {
                    try {
                      final restored = await c.restoreCityAdjustments();
                      if (context.mounted) {
                        showMessage(
                          context,
                          restored ? '已恢复该城市上次调整' : '该城市没有可恢复的调整',
                        );
                      }
                    } catch (_) {
                      if (context.mounted) showMessage(context, '读取上次调整失败，请重试');
                    }
                  },
                  child: const Text('恢复该城市上次调整'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ExpansionTile(
            key: PageStorageKey('bonus-deductions-${d.id}'),
            title: const Text(
              '奖金与扣除',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '年终奖 ${d.bonus.isEmpty ? '0' : d.bonus} 元 · 专项扣除 ${d.deduction.isEmpty ? '0' : d.deduction} 元/月',
              style: const TextStyle(fontSize: 12),
            ),
            childrenPadding: const EdgeInsets.all(18),
            children: [
              AmountField(
                label: '全年一次性奖金',
                value: d.bonus,
                optional: true,
                onChanged: (v) => c.update(c.draft.copyWith(bonus: v)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                key: ValueKey('bonus-month-${d.id}-${d.bonusMonth}'),
                initialValue: d.bonusMonth,
                decoration: const InputDecoration(labelText: '奖金发放月份'),
                items: [
                  for (var m = 1; m <= 12; m++)
                    DropdownMenuItem(value: m, child: Text('$m 月')),
                ],
                onChanged: (m) => c.update(c.draft.copyWith(bonusMonth: m)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: BonusMode.values
                    .map(
                      (m) => ChoiceChip(
                        label: Text(
                          {
                            BonusMode.compare: '比较两种方式',
                            BonusMode.separate: '单独计税',
                            BonusMode.merged: '并入工资',
                          }[m]!,
                        ),
                        selected: d.bonusMode == m,
                        onSelected: (_) =>
                            c.update(c.draft.copyWith(bonusMode: m)),
                      ),
                    )
                    .toList(),
              ),
              if (d.bonusMode != BonusMode.merged)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    '符合全年一次性奖金条件，本年未使用单独计税',
                    style: TextStyle(fontSize: 13),
                  ),
                  value: d.bonusEligible,
                  onChanged: (v) =>
                      c.update(c.draft.copyWith(bonusEligible: v)),
                ),
              const Divider(height: 28),
              AmountField(
                label: '专项附加扣除合计 / 月',
                value: d.deduction,
                optional: true,
                onChanged: (v) => c.update(c.draft.copyWith(deduction: v)),
              ),
              const SizedBox(height: 8),
              const Text(
                '填写实际申报合计，不包含每月 5,000 元基本减除费用。',
                style: TextStyle(fontSize: 12, color: payrollMuted),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<PensionMode>(
                key: ValueKey('pension-mode-${d.id}-${d.pensionMode}'),
                initialValue: d.pensionMode,
                decoration: const InputDecoration(labelText: '个人养老金'),
                items: const [
                  DropdownMenuItem(value: PensionMode.none, child: Text('不缴纳')),
                  DropdownMenuItem(
                    value: PensionMode.monthly,
                    child: Text('每月等额缴纳'),
                  ),
                  DropdownMenuItem(
                    value: PensionMode.once,
                    child: Text('指定月一次缴纳'),
                  ),
                ],
                onChanged: (v) => c.update(c.draft.copyWith(pensionMode: v)),
              ),
              if (d.pensionMode != PensionMode.none) ...[
                const SizedBox(height: 16),
                AmountField(
                  label: d.pensionMode == PensionMode.monthly
                      ? '每月缴费（全年不超过 12,000）'
                      : '本次缴费（不超过 12,000）',
                  value: d.pension,
                  onChanged: (v) => c.update(c.draft.copyWith(pension: v)),
                ),
                if (d.pensionMode == PensionMode.once) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    key: ValueKey('pension-month-${d.id}-${d.pensionMonth}'),
                    initialValue: d.pensionMonth,
                    decoration: const InputDecoration(labelText: '养老金缴费月份'),
                    items: [
                      for (var m = 1; m <= 12; m++)
                        DropdownMenuItem(value: m, child: Text('$m 月')),
                    ],
                    onChanged: (v) =>
                        c.update(c.draft.copyWith(pensionMonth: v)),
                  ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('留待年度汇算扣除', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('关闭时假设缴费当月及时提供凭证并预扣扣除'),
                  value: d.pensionAtSettlement,
                  onChanged: (v) =>
                      c.update(c.draft.copyWith(pensionAtSettlement: v)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        PolicyNotice(
          text: '${d.city.name} · 待核验参考参数\n按当前值估算全年；点击查看来源、适用期与缺口。',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CityPolicyScreen(city: d.city)),
          ),
        ),
        CheckboxListTile(
          key: const Key('estimate-confirmation'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text(
            '已核对参数及税前扣除口径，按当前值自定义估算全年',
            style: TextStyle(fontSize: 13),
          ),
          subtitle: const Text(
            '此模式将当前设置用于 12 个月，结果标注为估算。',
            style: TextStyle(fontSize: 12),
          ),
          value: d.estimateConfirmed,
          onChanged: (v) => c.update(c.draft.copyWith(estimateConfirmed: v)),
        ),
        const SizedBox(height: 8),
        if (c.results.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PayrollResultsScreen(results: c.results),
              ),
            ),
            child: Text(c.resultIsStale ? '查看上次结果（参数已修改）' : '查看本次结果'),
          ),
      ],
    );
  }
}

class CityPicker extends StatefulWidget {
  const CityPicker({super.key, required this.catalog, required this.current});
  final CityCatalog catalog;
  final String current;
  @override
  State<CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<CityPicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final cities = widget.catalog.search(query);
    return Scaffold(
      appBar: AppBar(title: const Text('选择城市')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              autofocus: false,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜索城市、拼音或首字母',
              ),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          if (query.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Wrap(
                spacing: 8,
                children: widget.catalog.cities
                    .where(
                      (c) =>
                          ['北京', '上海', '广州', '深圳', '杭州', '成都'].contains(c.name),
                    )
                    .map(
                      (c) => ActionChip(
                        label: Text(c.name),
                        onPressed: () => Navigator.pop(context, c),
                      ),
                    )
                    .toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${cities.length} 个城市 · 参考参数可手动调整',
                style: const TextStyle(color: payrollMuted, fontSize: 12),
              ),
            ),
          ),
          Expanded(
            child: cities.isEmpty
                ? const Center(child: Text('没有找到城市，请尝试其他名称或拼音'))
                : ListView.builder(
                    itemCount: cities.length,
                    itemBuilder: (context, i) {
                      final c = cities[i];
                      return ListTile(
                        title: Text(c.name),
                        subtitle: Text(
                          '${c.province} · ${c.yearLabel} · 待完整核验',
                        ),
                        trailing: Icon(
                          c.id == widget.current
                              ? Icons.check_circle
                              : Icons.chevron_right,
                          color: c.id == widget.current
                              ? payrollBlue
                              : payrollMuted,
                        ),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class CityPolicyScreen extends StatelessWidget {
  const CityPolicyScreen({super.key, required this.city});
  final CityReference city;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${city.name}参数来源')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PolicyNotice(text: city.note),
        const SizedBox(height: 16),
        Text(
          '采集版本：${city.version}\n下列链接是核对线索，链接存在不表示全部参数已核验。',
          style: const TextStyle(color: payrollMuted),
        ),
        const SizedBox(height: 16),
        for (final r in city.items)
          SectionCard(
            title: r.label,
            child: Column(
              children: [
                MetricRow(
                  '参考范围',
                  '${displayMoney(r.minBase)} – ${displayMoney(r.maxBase)}',
                ),
                MetricRow(
                  '个人 / 单位',
                  '${rateText(r.employeeRate)} / ${rateText(r.employerRate)}',
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        const Text(
          '来源链接',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        for (final url in city.sources)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(Uri.tryParse(url)?.host ?? '来源'),
            subtitle: Text(url, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () async {
              final uri = Uri.tryParse(url);
              if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
                return;
              }
              try {
                if (!await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    ) &&
                    context.mounted) {
                  showMessage(context, '无法打开链接');
                }
              } catch (_) {
                if (context.mounted) showMessage(context, '无法打开链接');
              }
            },
          ),
      ],
    ),
  );
}

class _ToolsScreen extends ConsumerWidget {
  const _ToolsScreen({required this.onHome});
  final VoidCallback onHome;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(payrollControllerProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SectionCard(
          title: '常用工具',
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.redeem_outlined, color: payrollBlue),
                title: const Text('工资与年终奖测算'),
                subtitle: const Text('比较单独计税和并入工资'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onHome,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.tune, color: payrollBlue),
                title: const Text('五险一金设置'),
                subtitle: Text('当前城市：${c.draft.city.name}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final next = await Navigator.push<PayrollDraft>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContributionsScreen(initial: c.draft),
                    ),
                  );
                  if (next != null) c.update(next);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.menu_book_outlined,
                  color: payrollBlue,
                ),
                title: const Text('规则与算法说明'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MethodologyScreen()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: '本地数据',
          child: Column(
            children: [
              MetricRow('已保存方案', '${c.plans.length} 份'),
              MetricRow('待恢复记录', '${c.recoveryCount} 条'),
              const Text(
                '工资、草稿和方案保存在本机。已保存结果不会随城市规则变化而重算。',
                style: TextStyle(color: payrollMuted, fontSize: 13),
              ),
              if (c.recoveryCount > 0)
                TextButton(
                  onPressed: () async {
                    try {
                      final text = await c.store.exportRecovery();
                      final file = await stagePayrollExport(
                        utf8.encode(text),
                        'json',
                      );
                      if (!context.mounted) return;
                      final box = context.findRenderObject() as RenderBox?;
                      await Share.shareXFiles(
                        [XFile(file.path)],
                        sharePositionOrigin: box == null
                            ? null
                            : box.localToGlobal(Offset.zero) & box.size,
                      );
                    } catch (_) {
                      if (context.mounted) showMessage(context, '备份导出失败，请重试');
                    }
                  },
                  child: const Text('导出原始恢复备份'),
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  if (await confirmAction(
                    context,
                    '清空所有本地薪酬数据？',
                    '将删除 ${c.plans.length} 份方案、草稿、旧版数据和恢复备份，并重建默认北京空白方案。此操作无法撤销。',
                  )) {
                    try {
                      await c.clearAll();
                      if (context.mounted) showMessage(context, '本地薪酬数据已清空');
                    } catch (_) {
                      if (context.mounted) showMessage(context, '清理未完成，请重试');
                    }
                  }
                },
                child: const Text('清空所有本地薪酬数据'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const PolicyNotice(
          text:
              '当前范围：居民个人、全年同一单位、固定月薪及一笔全年一次性奖金。账户缴费与到账现金分别展示。城市参考库包含待核验数据，自定义估算不等于工资单或申报结果。',
        ),
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: '薪酬测算',
            applicationVersion: '2.0',
          ),
          child: const Text('开源许可'),
        ),
      ],
    );
  }
}
