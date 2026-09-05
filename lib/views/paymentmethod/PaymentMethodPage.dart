import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';

class PaymentMethodPage extends StatefulWidget {
  const PaymentMethodPage({super.key, this.amount = 120000, this.concept = 'Reserva Suite Deluxe - Motel Fantasía'});

  final double amount;
  final String concept;

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  final _holder = TextEditingController(text: 'JUAN PÉREZ');
  final _number = TextEditingController(text: '4532 8812 9043 8892');
  final _expiry = TextEditingController(text: '12/28');
  final _cvv = TextEditingController(text: '882');
  bool _hideCvv = true;
  bool _loading = false;
  int _installments = 1;

  @override
  void dispose() {
    _holder.dispose();
    _number.dispose();
    _expiry.dispose();
    _cvv.dispose();
    super.dispose();
  }

  String _money(double value) {
    final text = value.round().toString();
    final formatted = text.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.');
    return '\$$formatted COP';
  }

  Future<void> _pay() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _loading = false);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pago exitoso'),
        content: Text('Se simuló el pago de ${_money(widget.amount)}.'),
        actions: [AppButton(label: 'Entendido', expanded: false, onPressed: () => Navigator.pop(context))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(title: const Text('Método de pago'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Total a pagar', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
                const Chip(avatar: Icon(Icons.shield_outlined, size: 15), label: Text('Sandbox')),
              ]),
              Text(_money(widget.amount), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text(widget.concept, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textSecondary)),
            ])),
            const SizedBox(height: AppSpacing.s5),
            _CardPreview(holder: _holder, number: _number, expiry: _expiry),
            const SizedBox(height: AppSpacing.s6),
            Text('Detalles de la tarjeta', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.s3),
            AppTextField(label: 'Nombre del titular', controller: _holder, prefixIcon: const Icon(Icons.person_outline)),
            const SizedBox(height: AppSpacing.s3),
            AppTextField(label: 'Número de tarjeta', controller: _number, keyboardType: TextInputType.number, prefixIcon: const Icon(Icons.credit_card_outlined)),
            const SizedBox(height: AppSpacing.s3),
            Row(children: [
              Expanded(child: AppTextField(label: 'Vencimiento', controller: _expiry, hint: 'MM/YY', keyboardType: TextInputType.datetime)),
              const SizedBox(width: AppSpacing.s3),
              Expanded(child: AppTextField(label: 'CVV', controller: _cvv, obscureText: _hideCvv, keyboardType: TextInputType.number, suffixIcon: IconButton(tooltip: 'Mostrar CVV', icon: Icon(_hideCvv ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _hideCvv = !_hideCvv)))),
            ]),
            const SizedBox(height: AppSpacing.s3),
            DropdownButtonFormField<int>(initialValue: _installments, decoration: const InputDecoration(labelText: 'Cuotas'), items: List.generate(12, (index) => index + 1).map((value) => DropdownMenuItem(value: value, child: Text(value == 1 ? '1 cuota sin interés' : '$value cuotas'))).toList(), onChanged: (value) => setState(() => _installments = value ?? 1)),
            const SizedBox(height: AppSpacing.s5),
            AppCard(child: Row(children: [const Icon(Icons.lock_outline, color: AppColors.violet), const SizedBox(width: AppSpacing.s3), Expanded(child: Text('Transacción cifrada y protegida. Esta pantalla usa datos de simulación.', style: TextStyle(color: colors.textSecondary)))])),
            const SizedBox(height: AppSpacing.s5),
            AppButton(label: _loading ? 'Procesando...' : 'Pagar ${_money(widget.amount)}', loading: _loading, onPressed: _pay),
          ]),
        ),
      ),
    );
  }
}

class _CardPreview extends StatelessWidget {
  const _CardPreview({required this.holder, required this.number, required this.expiry});
  final TextEditingController holder;
  final TextEditingController number;
  final TextEditingController expiry;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<TextEditingValue>(
        valueListenable: holder,
        builder: (context, holderValue, child) => ValueListenableBuilder<TextEditingValue>(
          valueListenable: number,
          builder: (context, numberValue, child) => ValueListenableBuilder<TextEditingValue>(
            valueListenable: expiry,
            builder: (context, expiryValue, child) => Container(
              height: 190,
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.s5),
              decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: AppShadows.cta),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(Icons.nfc, color: Colors.white, size: 32), Text('VISA', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic))]),
                Text(numberValue.text.isEmpty ? '•••• •••• •••• ••••' : numberValue.text, style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2)),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(holderValue.text.isEmpty ? 'NOMBRE DEL TITULAR' : holderValue.text.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(expiryValue.text.isEmpty ? 'MM/YY' : expiryValue.text, style: const TextStyle(color: Colors.white))]),
              ]),
            ),
          ),
        ),
      );
}
