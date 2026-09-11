import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState()=>_LoginPageState();
}
class _LoginPageState extends ConsumerState<LoginPage> {
  final email=TextEditingController(),password=TextEditingController();
  bool register=false,verificationSent=false;
  @override
  void dispose(){email.dispose();password.dispose();super.dispose();}
  @override
  Widget build(BuildContext context) {
    final api=ref.read(apiProvider);
    return Scaffold(body:PageBody(children:[
      const SizedBox(height:64),Icon(Icons.eco_outlined,size:44,color:Theme.of(context).colorScheme.primary),
      const SizedBox(height:24),Text(context.t('eatme'),style:Theme.of(context).textTheme.displaySmall,textAlign:TextAlign.center),
      const SizedBox(height:12),Text(context.t('tagline'),textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:48),AutofillGroup(child:Column(children:[
        TextField(controller:email,keyboardType:TextInputType.emailAddress,autofillHints:const [AutofillHints.email],
          decoration:InputDecoration(labelText:context.t('email'))),const SizedBox(height:12),
        TextField(controller:password,obscureText:true,autofillHints:[register?AutofillHints.newPassword:AutofillHints.password],
          decoration:InputDecoration(labelText:context.t('password'),helperText:context.t('password_hint'))),
      ])),const SizedBox(height:24),
      AsyncAction(label:context.t(register?'create_account':'login'),action:() async {
        final signedIn=await api.login(email.text.trim(),password.text,register:register);
        if(signedIn) {await ref.read(appProvider.notifier).hydrate();}
        else if(mounted) {setState(()=>verificationSent=true);}
      }),
      TextButton(onPressed:()=>setState(()=>register=!register),child:Text(context.t(register?'have_account':'new_account'))),
      if(verificationSent) StatusNote(text:context.t('verify_email')),
      if(!EatMeApi.development) AsyncAction(label:context.t('forgot_password'),secondary:true,action:() async {
        await api.resetPassword(email.text.trim());
        if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(context.t('reset_sent'))));
      }),
      if(!EatMeApi.development&&EatMeApi.oauthEnabled)...[
        const SizedBox(height:24),AsyncAction(label:context.t('google'),secondary:true,action:()=>api.oauth(OAuthProvider.google)),
        const SizedBox(height:12),AsyncAction(label:context.t('apple'),secondary:true,action:()=>api.oauth(OAuthProvider.apple)),
      ],
      if(EatMeApi.development) StatusNote(text:context.t('development_login')),
    ]));
  }
}

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});
  @override
  State<ResetPasswordPage> createState()=>_ResetPasswordPageState();
}
class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final password=TextEditingController();
  @override
  void dispose(){password.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(context.t('reset_password'))),body:PageBody(children:[
    TextField(controller:password,obscureText:true,decoration:InputDecoration(labelText:context.t('new_password'))),
    const SizedBox(height:24),AsyncAction(label:context.t('save'),action:() async {
      if(password.text.length<12) throw const ApiFailure('password_length');
      await Supabase.instance.client.auth.updateUser(UserAttributes(password:password.text));
      if(context.mounted) Navigator.of(context).pop();
    }),
  ]));
}
