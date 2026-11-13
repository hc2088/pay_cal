import 'package:flutter/material.dart';
import '../../calculation/money_format.dart';
import '../../domain/payroll_models.dart';

const payrollBlue = Color(0xFF2956D9);
const payrollInk = Color(0xFF142846);
const payrollMuted = Color(0xFF6D7C91);

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
  });
  final Widget child;
  final String? title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    ),
  );
}

class AmountField extends StatefulWidget {
  const AmountField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint = '0.00',
    this.rate = false,
    this.optional = false,
    this.helper,
    this.autofocus = false,
    this.labelAbove = false,
  });
  final String label, value, hint;
  final bool rate, optional, autofocus, labelAbove;
  final String? helper;
  final ValueChanged<String> onChanged;
  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  // ExpansionTile stores a bool in PageStorage. Text input scroll positions
  // must not read that shared ancestor entry as a double when remounted.
  final scrollController = ScrollController(keepScrollOffset: false);
  late final TextEditingController controller = TextEditingController(
    text: widget.value,
  );
  @override
  void didUpdateWidget(covariant AmountField old) {
    super.didUpdateWidget(old);
    if (controller.text != widget.value) {
      controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invalid =
        widget.value.isNotEmpty &&
        parseDecimal(
              widget.value,
              widget.rate ? 4 : 2,
              max: widget.rate ? rateScale : moneyLimit,
            ) ==
            null;
    final input = TextField(
      controller: controller,
      scrollController: scrollController,
      autofocus: widget.autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.labelAbove ? null : widget.label,
        hintText: widget.hint,
        hintMaxLines: widget.labelAbove ? 3 : null,
        suffixText: widget.rate ? '%' : '元',
        helperText: widget.helper,
        helperMaxLines: 3,
        errorText: invalid ? '请输入有效的非负${widget.rate ? '比例' : '金额'}' : null,
        errorMaxLines: 3,
      ),
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
    );
    return widget.labelAbove
        ? LabeledField(label: widget.label, child: input)
        : input;
  }
}

// Floating outline labels paint above the input's bounds and can be clipped by
// an ExpansionTile. Keep labels inside the layout and allow long labels to wrap.
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ExcludeSemantics(
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: payrollInk),
        ),
      ),
      const SizedBox(height: 8),
      Semantics(label: label, child: child),
    ],
  );
}

class MetricRow extends StatelessWidget {
  const MetricRow(
    this.label,
    this.value, {
    super.key,
    this.emphasis = false,
    this.highlightLabel = false,
  });
  final String label, value;
  final bool emphasis, highlightLabel;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: LayoutBuilder(
      builder: (context, box) {
        final style = TextStyle(
          fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
          color: emphasis ? payrollBlue : payrollInk,
        );
        final labelStyle = TextStyle(
          color: highlightLabel ? payrollBlue : payrollMuted,
          fontWeight: highlightLabel ? FontWeight.w700 : null,
        );
        if (MediaQuery.textScalerOf(context).scale(1) > 1.4) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: labelStyle),
              Text(value, style: style),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: labelStyle)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(value, style: style, textAlign: TextAlign.right),
            ),
          ],
        );
      },
    ),
  );
}

class PolicyNotice extends StatelessWidget {
  const PolicyNotice({super.key, required this.text, this.onTap});
  final String text;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFEDF2FF),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 19, color: payrollBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF40557A),
                  height: 1.5,
                ),
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, size: 18, color: payrollBlue),
          ],
        ),
      ),
    ),
  );
}

String displayMoney(int? cents) => cents == null ? '未记录' : formatCents(cents);
String displayDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
void showMessage(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));
Future<String?> askName(BuildContext context, String initial) async {
  var value = initial;
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('方案名称'),
      content: TextFormField(
        initialValue: initial,
        maxLength: 60,
        autofocus: true,
        onChanged: (v) => value = v,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}

Future<bool> confirmAction(
  BuildContext context,
  String title,
  String body,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    ) ??
    false;
