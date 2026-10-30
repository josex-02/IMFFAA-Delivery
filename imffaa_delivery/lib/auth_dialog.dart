part of 'main.dart';

class AuthResult {
  const AuthResult(
      {required this.name,
      required this.email,
      required this.idNumber,
      this.role = 'cliente',
      this.userId});
  final String? userId;
  final String name;
  final String email;
  final String idNumber;

  /// Debe venir de la respuesta autenticada del backend, nunca de un campo editable por el usuario.
  final String role;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        name: (json['name'] ?? json['nombre'] ?? '').toString(),
        email: (json['email'] ?? json['correo'] ?? '').toString(),
        idNumber:
            (json['idNumber'] ?? json['numero_identidad'] ?? '').toString(),
        role:
            (json['role'] ?? json['rol'] ?? 'cliente').toString().toLowerCase(),
        userId: (json['id'] ?? json['user_id'])?.toString(),
      );
}

class AuthDialog extends StatefulWidget {
  const AuthDialog({super.key});

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
  final loginKey = GlobalKey<FormState>();
  final registerKey = GlobalKey<FormState>();
  final loginEmail = TextEditingController();
  final loginPassword = TextEditingController();
  final fullName = TextEditingController();
  final idNumber = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final verificationCode = TextEditingController();
  final recoveryCode = TextEditingController();
  final newPassword = TextEditingController();
  final confirmNewPassword = TextEditingController();
  final picker = ImagePicker();
  XFile? idImage;
  bool isLogin = true;
  bool obscureLogin = true;
  bool obscureRegister = true;
  bool acceptedPrivacy = false;
  bool awaitingEmailCode = false;
  bool recoveringPassword = false;
  bool recoveryCodeVerified = false;

  @override
  void dispose() {
    loginEmail.dispose();
    loginPassword.dispose();
    fullName.dispose();
    idNumber.dispose();
    phone.dispose();
    email.dispose();
    password.dispose();
    verificationCode.dispose();
    recoveryCode.dispose();
    newPassword.dispose();
    confirmNewPassword.dispose();
    super.dispose();
  }

  Future<void> chooseIdImage() async {
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked != null && mounted) setState(() => idImage = picked);
  }

  String? requiredValue(String? value, String label) {
    if (value == null || value.trim().isEmpty) return 'Ingresa $label';
    return null;
  }

  String? validEmail(String? value) {
    if (value == null ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
      return 'Ingresa un correo válido';
    }
    return null;
  }

  Future<void> verifyEmailCode() async {
    final code = verificationCode.text.trim();
    if (!RegExp(r'^\d{8}$').hasMatch(code)) {
      showAppToast(context,
          'Escribe el código de verificación que recibiste por correo.',
          isError: true);
      return;
    }
    try {
      final result = await supabase.auth.verifyOTP(
        email: email.text.trim(),
        token: code,
        type: OtpType.signup,
      );
      final user = result.user;
      if (user == null || result.session == null) {
        throw const AuthException(
            'No se pudo verificar el correo. Revisa el código e inténtalo de nuevo.');
      }
      await supabase.from('profiles').upsert({
        'id': user.id,
        'full_name': fullName.text.trim().isNotEmpty
            ? fullName.text.trim()
            : (user.userMetadata?['full_name'] ?? '').toString(),
        'id_number': idNumber.text.trim().isNotEmpty
            ? idNumber.text.trim()
            : (user.userMetadata?['id_number'] ?? '').toString(),
        'phone': phone.text.trim().isNotEmpty
            ? phone.text.trim()
            : (user.userMetadata?['phone'] ?? '').toString(),
        'role': 'cliente',
      });
      if (idImage != null) {
        final bytes = await idImage!.readAsBytes();
        final path =
            '${user.id}/identidad_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage.from('identity-documents').uploadBinary(
            path, bytes,
            fileOptions:
                const FileOptions(contentType: 'image/jpeg', upsert: true));
      }
      if (!mounted) return;
      showAppToast(context, 'Correo verificado correctamente.');
      Navigator.of(context).pop(AuthResult(
          userId: user.id,
          name: (user.userMetadata?['full_name'] ?? fullName.text.trim())
              .toString(),
          email: user.email ?? email.text.trim(),
          idNumber: (user.userMetadata?['id_number'] ?? idNumber.text.trim())
              .toString(),
          role: 'cliente'));
    } on AuthException catch (e) {
      if (mounted) showAppToast(context, e.message, isError: true);
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'No se pudo verificar el correo: $e',
            isError: true);
      }
    }
  }

  Future<void> requestPasswordRecovery() async {
    final value = loginEmail.text.trim();
    final emailError = validEmail(value);
    if (emailError != null) {
      showAppToast(context, emailError, isError: true);
      return;
    }
    try {
      await supabase.auth.resetPasswordForEmail(value);
      if (!mounted) return;
      setState(() {
        recoveringPassword = true;
        recoveryCodeVerified = false;
      });
      showAppToast(context,
          'Enviamos un código para restablecer tu contraseña. Revisa tu correo.');
    } on AuthException catch (e) {
      if (mounted) showAppToast(context, e.message, isError: true);
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'No se pudo enviar el código: $e', isError: true);
      }
    }
  }

  Future<void> verifyPasswordRecoveryCode() async {
    final code = recoveryCode.text.trim();
    if (!RegExp(r'^\d{6,8}$').hasMatch(code)) {
      showAppToast(context, 'Escribe el código recibido por correo.',
          isError: true);
      return;
    }
    try {
      final response = await supabase.auth.verifyOTP(
        email: loginEmail.text.trim(),
        token: code,
        type: OtpType.recovery,
      );
      if (response.user == null || response.session == null) {
        throw const AuthException(
            'No se pudo verificar el código. Revisa el código e inténtalo de nuevo.');
      }
      if (mounted) setState(() => recoveryCodeVerified = true);
    } on AuthException catch (e) {
      if (mounted) showAppToast(context, e.message, isError: true);
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'No se pudo verificar el código: $e',
            isError: true);
      }
    }
  }

  Future<void> submitNewPassword() async {
    if (newPassword.text.length < 8) {
      showAppToast(context, 'Usa al menos 8 caracteres para la contraseña.',
          isError: true);
      return;
    }
    if (newPassword.text != confirmNewPassword.text) {
      showAppToast(context, 'Las contraseñas no coinciden.', isError: true);
      return;
    }
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw const AuthException(
            'La sesión de recuperación expiró. Solicita un nuevo código.');
      }
      final profile = await supabase
          .from('profiles')
          .select('full_name, id_number, role')
          .eq('id', user.id)
          .maybeSingle();
      final response = await supabase.auth
          .updateUser(UserAttributes(password: newPassword.text));
      final updatedUser = response.user ?? user;
      if (!mounted) return;
      showAppToast(context, 'Contraseña actualizada correctamente.');
      Navigator.of(context).pop(AuthResult(
        userId: updatedUser.id,
        name: (profile?['full_name'] ??
                updatedUser.userMetadata?['full_name'] ??
                updatedUser.email?.split('@').first ??
                'Cliente')
            .toString(),
        email: updatedUser.email ?? loginEmail.text.trim(),
        idNumber: (profile?['id_number'] ??
                updatedUser.userMetadata?['id_number'] ??
                '')
            .toString(),
        role: (profile?['role'] ?? 'cliente').toString().toLowerCase(),
      ));
    } on AuthException catch (e) {
      if (mounted) showAppToast(context, e.message, isError: true);
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'No se pudo actualizar la contraseña: $e',
            isError: true);
      }
    }
  }

  void cancelPasswordRecovery() {
    setState(() {
      recoveringPassword = false;
      recoveryCodeVerified = false;
      recoveryCode.clear();
      newPassword.clear();
      confirmNewPassword.clear();
    });
  }

  Future<void> submitLogin() async {
    if (!(loginKey.currentState?.validate() ?? false)) return;
    try {
      final response = await supabase.auth.signInWithPassword(
        email: loginEmail.text.trim(),
        password: loginPassword.text,
      );
      final user = response.user;
      if (user == null) throw const AuthException('No se pudo iniciar sesión.');
      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      Navigator.of(context).pop(AuthResult(
        userId: user.id,
        name: (profile?['full_name'] ??
                user.userMetadata?['full_name'] ??
                user.email?.split('@').first ??
                'Cliente')
            .toString(),
        email: user.email ?? loginEmail.text.trim(),
        idNumber: (profile?['id_number'] ?? '').toString(),
        role: (profile?['role'] ?? 'cliente').toString().toLowerCase(),
      ));
    } on AuthException catch (e) {
      if (mounted) showAppToast(context, e.message, isError: true);
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'No se pudo iniciar sesión: $e', isError: true);
      }
    }
  }

  Future<void> submitRegistration() async {
    if (!(registerKey.currentState?.validate() ?? false)) return;
    if (idImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecciona una foto de tu documento de identidad.')),
      );
      return;
    }
    if (!acceptedPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Debes aceptar el aviso de privacidad para continuar.')),
      );
      return;
    }
    try {
      // Supabase Auth gestiona el hash de la contraseña en el servidor; nunca la guardes en profiles.
      final response = await supabase.auth.signUp(
        email: email.text.trim(),
        password: password.text,
        data: {
          'full_name': fullName.text.trim(),
          'id_number': idNumber.text.trim(),
          'phone': phone.text.trim()
        },
      );
      final user = response.user;
      if (user == null) {
        throw const AuthException('No se pudo crear la cuenta.');
      }
      if (response.session == null) {
        if (mounted) {
          setState(() => awaitingEmailCode = true);
          showAppToast(context,
              'Te enviamos un código de verificación. Revisa tu correo.');
        }
        return;
      }
      await supabase.from('profiles').upsert({
        'id': user.id,
        'full_name': fullName.text.trim(),
        'id_number': idNumber.text.trim(),
        'phone': phone.text.trim(),
        'role': 'cliente',
      });
      final imageBytes = await idImage!.readAsBytes();
      final imagePath =
          '${user.id}/identidad_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('identity-documents').uploadBinary(
            imagePath,
            imageBytes,
            fileOptions:
                const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      if (!mounted) return;
      Navigator.of(context).pop(AuthResult(
        userId: user.id,
        name: fullName.text.trim(),
        email: email.text.trim(),
        idNumber: idNumber.text.trim(),
        role: 'cliente',
      ));
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo crear la cuenta: $e')));
      }
    }
  }

  InputDecoration fieldDecoration(String label,
          {String? hint, Widget? prefix}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefix,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Dialog(
      insetPadding:
          EdgeInsets.symmetric(horizontal: width < 450 ? 12 : 28, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: 480, maxHeight: MediaQuery.sizeOf(context).height * .9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: navy, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.verified_user_outlined,
                        color: Color.fromARGB(255, 187, 186, 175)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Acceso a IMFFAA Delivery',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text('Identifícate para añadir artículos al carrito',
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                      ],
                    ),
                  ),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Builder(builder: (context) {
                final scheme = Theme.of(context).colorScheme;
                final darkMode = scheme.brightness == Brightness.dark;
                return Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: darkMode
                          ? const Color(0xFF171B18)
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: scheme.outlineVariant)),
                  child: Row(
                    children: [
                      Expanded(child: _tabButton('Iniciar sesión', isLogin)),
                      Expanded(child: _tabButton('Crear cuenta', !isLogin)),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: isLogin ? _loginForm() : _registerForm(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, bool selected) {
    final scheme = Theme.of(context).colorScheme;
    final darkMode = scheme.brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () => setState(() {
        isLogin = label == 'Iniciar sesión';
        awaitingEmailCode = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 5),
        decoration: BoxDecoration(
            color: selected
                ? darkMode
                    ? const Color(0xFF28583A)
                    : scheme.surface
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: scheme.shadow.withValues(alpha: .12),
                        blurRadius: 5,
                        offset: const Offset(0, 2))
                  ]
                : null),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected
                    ? darkMode
                        ? scheme.onPrimaryContainer
                        : scheme.primary
                    : scheme.onSurfaceVariant)),
      ),
    );
  }

  Widget _loginForm() {
    if (recoveringPassword) return _passwordRecoveryForm();
    return Form(
      key: loginKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 5),
          const Text('Bienvenido de nuevo',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(
              'El catálogo se puede consultar sin cuenta. Inicia sesión para intentar añadir artículos.',
              style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          TextFormField(
              controller: loginEmail,
              keyboardType: TextInputType.emailAddress,
              validator: validEmail,
              decoration: fieldDecoration('Correo electrónico',
                  prefix: const Icon(Icons.mail_outline))),
          const SizedBox(height: 12),
          TextFormField(
              controller: loginPassword,
              obscureText: obscureLogin,
              validator: (v) => requiredValue(v, 'tu contraseña'),
              decoration: fieldDecoration(
                'Contraseña',
                prefix: const Icon(Icons.lock_outline),
                hint: 'Tu contraseña',
              ).copyWith(
                  suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => obscureLogin = !obscureLogin),
                      icon: Icon(obscureLogin
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined)))),
          const SizedBox(height: 16),
          SizedBox(
              height: 48,
              child: FilledButton(
                  onPressed: submitLogin,
                  style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  child: const Text('INICIAR SESIÓN'))),
          Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                  onPressed: requestPasswordRecovery,
                  icon: const Icon(Icons.lock_reset_rounded, size: 17),
                  label: const Text('¿Olvidaste tu contraseña?'))),
          const SizedBox(height: 8),
          _demoNotice(),
        ],
      ),
    );
  }

  Widget _passwordRecoveryForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 5),
          Text(
              recoveryCodeVerified
                  ? 'Crear una nueva contraseña'
                  : 'Restablecer contraseña',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
              recoveryCodeVerified
                  ? 'Elige una contraseña nueva para tu cuenta.'
                  : 'Enviamos un código a ${loginEmail.text.trim()}. Escríbelo para continuar.',
              style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          if (!recoveryCodeVerified) ...[
            TextField(
                controller: recoveryCode,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                textAlign: TextAlign.center,
                maxLength: 8,
                decoration:
                    fieldDecoration('Código de recuperación', hint: '000000')),
            const SizedBox(height: 8),
            SizedBox(
                height: 48,
                child: FilledButton(
                    onPressed: verifyPasswordRecoveryCode,
                    child: const Text('VERIFICAR CÓDIGO'))),
            Align(
                alignment: Alignment.center,
                child: TextButton(
                    onPressed: requestPasswordRecovery,
                    child: const Text('Reenviar código'))),
          ] else ...[
            TextField(
                controller: newPassword,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: fieldDecoration('Nueva contraseña',
                    prefix: const Icon(Icons.lock_outline))),
            const SizedBox(height: 12),
            TextField(
                controller: confirmNewPassword,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: fieldDecoration('Confirmar contraseña',
                    prefix: const Icon(Icons.lock_outline))),
            const SizedBox(height: 16),
            SizedBox(
                height: 48,
                child: FilledButton(
                    onPressed: submitNewPassword,
                    child: const Text('ACTUALIZAR CONTRASEÑA'))),
          ],
          TextButton(
              onPressed: cancelPasswordRecovery,
              child: const Text('Volver a iniciar sesión')),
        ],
      );

  Widget _registerForm() {
    if (awaitingEmailCode) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 8),
        const Icon(Icons.mark_email_read_outlined, size: 42, color: navy),
        const SizedBox(height: 12),
        const Text('Verifica tu correo',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(
            'Introduce el código que enviamos a ${email.text.trim()}. Puedes abrir el correo en otro dispositivo y escribir aquí el mismo código.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 18),
        TextField(
            controller: verificationCode,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            textAlign: TextAlign.center,
            maxLength: 8,
            decoration:
                fieldDecoration('Código de verificación', hint: '000000')),
        const SizedBox(height: 8),
        SizedBox(
            height: 48,
            child: FilledButton(
                onPressed: verifyEmailCode,
                child: const Text('VERIFICAR CORREO'))),
        Align(
            alignment: Alignment.center,
            child: TextButton(
                onPressed: () async {
                  try {
                    await supabase.auth
                        .resend(type: OtpType.signup, email: email.text.trim());
                    if (mounted) {
                      showAppToast(
                          context, 'Enviamos otro código de verificación.');
                    }
                  } on AuthException catch (e) {
                    if (mounted) {
                      showAppToast(context, e.message, isError: true);
                    }
                  }
                },
                child: const Text('Reenviar código'))),
        TextButton(
            onPressed: () => setState(() => awaitingEmailCode = false),
            child: const Text('Volver al registro')),
      ]);
    }
    return Form(
      key: registerKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 5),
          const Text('Crear una cuenta',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(
              'Usaremos estos datos para que el servidor pueda verificar tu identidad y permisos.',
              style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          TextFormField(
              controller: fullName,
              textCapitalization: TextCapitalization.words,
              validator: (v) => requiredValue(v, 'tu nombre completo'),
              decoration: fieldDecoration('Nombre completo',
                  prefix: const Icon(Icons.person_outline))),
          const SizedBox(height: 11),
          TextFormField(
              controller: idNumber,
              keyboardType: TextInputType.number,
              validator: (v) => requiredValue(v, 'tu número de identidad'),
              decoration: fieldDecoration('Número de identidad',
                  hint: 'Como aparece en tu documento',
                  prefix: const Icon(Icons.badge_outlined))),
          const SizedBox(height: 11),
          TextFormField(
              controller: phone,
              keyboardType: TextInputType.phone,
              validator: (v) => requiredValue(v, 'tu número de teléfono'),
              decoration: fieldDecoration('Teléfono',
                  prefix: const Icon(Icons.phone_outlined))),
          const SizedBox(height: 11),
          TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              validator: validEmail,
              decoration: fieldDecoration('Correo electrónico',
                  prefix: const Icon(Icons.mail_outline))),
          const SizedBox(height: 11),
          TextFormField(
              controller: password,
              obscureText: obscureRegister,
              validator: (v) => v == null || v.length < 8
                  ? 'Usa al menos 8 caracteres'
                  : null,
              decoration: fieldDecoration('Crear contraseña',
                      prefix: const Icon(Icons.lock_outline))
                  .copyWith(
                      suffixIcon: IconButton(
                          onPressed: () => setState(
                              () => obscureRegister = !obscureRegister),
                          icon: Icon(obscureRegister
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined)))),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: chooseIdImage,
            style: OutlinedButton.styleFrom(
                foregroundColor: navy,
                side: const BorderSide(color: line),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11))),
            icon: Icon(
                idImage == null
                    ? Icons.add_a_photo_outlined
                    : Icons.check_circle_outline,
                color: idImage == null ? slate : Colors.green),
            label: Text(
                idImage == null
                    ? 'Subir foto del documento de identidad'
                    : 'Documento seleccionado · cambiar foto',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
          if (idImage != null) ...[
            const SizedBox(height: 8),
            FutureBuilder<Uint8List>(
              future: idImage!.readAsBytes(),
              builder: (context, snapshot) => snapshot.hasData
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(snapshot.data!,
                          height: 130, fit: BoxFit.contain))
                  : const Padding(
                      padding: EdgeInsets.all(12),
                      child: LinearProgressIndicator()),
            ),
          ],
          const SizedBox(height: 8),
          CheckboxListTile(
            value: acceptedPrivacy,
            onChanged: (value) =>
                setState(() => acceptedPrivacy = value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: const Text(
                'Acepto el aviso de privacidad y el uso de estos datos para verificar mi identidad.',
                style: TextStyle(fontSize: 11, height: 1.4)),
          ),
          const SizedBox(height: 8),
          SizedBox(
              height: 48,
              child: FilledButton(
                  onPressed: submitRegistration,
                  style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  child: const Text('CREAR CUENTA'))),
          const SizedBox(height: 8),
          _demoNotice(),
        ],
      ),
    );
  }

  Widget _demoNotice() => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
            color: const Color(0xFFFFF6DF),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFFEAD8A8))),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded,
                size: 17, color: Color(0xFF775B17)),
            SizedBox(width: 8),
            Expanded(
                child: Text(
                    'Tu cuenta se registra mediante Supabase Auth. Los permisos dependen del rol almacenado en tu perfil.',
                    style: TextStyle(
                        fontSize: 10, height: 1.45, color: Color(0xFF775B17)))),
          ],
        ),
      );
}
