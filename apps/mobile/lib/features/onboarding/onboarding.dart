import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key,this.edit=false});
  final bool edit;
  @override
  ConsumerState<OnboardingPage> createState()=>_OnboardingPageState();
}
class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final name=TextEditingController(),timezone=TextEditingController(text:'Europe/Rome');
  final mutation=Mutation();
  int step=0,size=1;
  bool adult=false,consent=false,medicalConsent=false;
  String strictness='standard';
  final Set<String> selected={},allergies={},intolerances={};
  @override
  void initState() {
    super.initState();
    final state=ref.read(appProvider);
    final profile=state.profile;
    if(widget.edit) {
      name.text=profile['name'] as String? ?? '';
      size=profile['household_size'] as int? ?? 1;
      final settings=Map<String,dynamic>.from(profile['settings'] as Map);
      timezone.text=settings['timezone'] as String;
      selected.addAll((settings['diets'] as List).map((d)=>d['diet_id'] as String));
      allergies.addAll(List<String>.from(settings['allergies'] as List));
      intolerances.addAll(List<String>.from(settings['intolerances'] as List));
      if((settings['diets'] as List).isNotEmpty) strictness=settings['diets'][0]['strictness'] as String;
      adult=true;consent=allergies.isNotEmpty||intolerances.isNotEmpty;
    } else {
      for(final diet in state.diets) {if(diet.slug=='mediterranean'&&diet.selectable) selected.add(diet.id);}
    }
  }
  @override
  void dispose(){name.dispose();timezone.dispose();super.dispose();}
  @override
  Widget build(BuildContext context) {
    final state=ref.watch(appProvider);
    return Scaffold(appBar:AppBar(title:Text(context.t(widget.edit?'edit_profile':'make_it_yours')),
      leading:step>0?IconButton(tooltip:context.t('back'),icon:const Icon(Icons.arrow_back),onPressed:()=>setState(()=>step--)):null),
      body:PageBody(children:[
        Text(context.t('step_count',{'current':step+1,'total':3}),style:Theme.of(context).textTheme.labelLarge),
        const SizedBox(height:24),
        if(step==0)...[
          Text(context.t('welcome_title'),style:Theme.of(context).textTheme.displaySmall),const SizedBox(height:28),
          TextField(controller:name,decoration:InputDecoration(labelText:context.t('name'))),const SizedBox(height:24),
          Text(context.t('household_question'),style:Theme.of(context).textTheme.titleMedium),
          Row(children:[IconButton(tooltip:context.t('fewer'),onPressed:size>1?()=>setState(()=>size--):null,icon:const Icon(Icons.remove)),
            Text('$size',style:Theme.of(context).textTheme.headlineMedium),
            IconButton(tooltip:context.t('more'),onPressed:size<20?()=>setState(()=>size++):null,icon:const Icon(Icons.add))]),
          CheckboxListTile(contentPadding:EdgeInsets.zero,title:Text(context.t('adult_confirmation')),value:adult,onChanged:(v)=>setState(()=>adult=v??false)),
        ],
        if(step==1)...[
          Text(context.t('diet_question'),style:Theme.of(context).textTheme.displaySmall),const SizedBox(height:12),
          Text(context.t('diet_hint')),const SizedBox(height:24),
          for(final diet in state.diets.where((d)=>d.selectable)) CheckboxListTile(contentPadding:EdgeInsets.zero,
            title:Text(localized(diet.name,context.language)),value:selected.contains(diet.id),
            onChanged:(v)=>setState((){if(v==true){selected.add(diet.id);}else{selected.remove(diet.id);}})),
          const SizedBox(height:20),DropdownButtonFormField<String>(initialValue:strictness,
            decoration:InputDecoration(labelText:context.t('strictness')),
            items:['flexible','standard','strict'].map((s)=>DropdownMenuItem(value:s,child:Text(context.t(s)))).toList(),
            onChanged:(s)=>setState(()=>strictness=s!)),
          ExpansionTile(tilePadding:EdgeInsets.zero,title:Text(context.t('medical_nutrition')),children:[
            StatusNote(text:context.t('medical_review_note')),
            for(final diet in state.diets.where((d)=>!d.selectable)) ListTile(contentPadding:EdgeInsets.zero,
              title:Text(localized(diet.name,context.language)),subtitle:Text(context.t('requires_review'))),
          ]),
        ],
        if(step==2)...[
          Text(context.t('restrictions_title'),style:Theme.of(context).textTheme.displaySmall),const SizedBox(height:12),
          Text(context.t('restrictions_hint')),const SizedBox(height:16),
          ExpansionTile(tilePadding:EdgeInsets.zero,initiallyExpanded:allergies.isNotEmpty,title:Text(context.t('allergies')),
            subtitle:Text(context.t('selected_count',{'count':allergies.length})),children:[
              Wrap(spacing:8,runSpacing:8,children:state.allergens.map((a)=>FilterChip(label:Text(context.t('allergen_$a')),
                selected:allergies.contains(a),onSelected:(v)=>setState((){if(v){allergies.add(a);}else{allergies.remove(a);}}))).toList()),
            ]),
          ExpansionTile(tilePadding:EdgeInsets.zero,title:Text(context.t('intolerances')),initiallyExpanded:intolerances.isNotEmpty,
            children:[CheckboxListTile(title:Text(context.t('lactose')),value:intolerances.contains('lactose'),onChanged:(v)=>setState((){
              if(v==true){intolerances.add('lactose');}else{intolerances.remove('lactose');}
            }))]),
          if(allergies.isNotEmpty||intolerances.isNotEmpty) CheckboxListTile(contentPadding:EdgeInsets.zero,
            title:Text(context.t('health_consent')),value:consent,onChanged:(v)=>setState(()=>consent=v??false)),
          if(state.diets.any((d)=>d.medical&&selected.contains(d.id))) CheckboxListTile(contentPadding:EdgeInsets.zero,
            title:Text(context.t('medical_consent')),value:medicalConsent,onChanged:(v)=>setState(()=>medicalConsent=v??false)),
          ExpansionTile(tilePadding:EdgeInsets.zero,title:Text(context.t('date_settings')),
            children:[TextField(controller:timezone,decoration:InputDecoration(labelText:context.t('timezone')))]),
        ],
        const SizedBox(height:32),
        if(step<2) FilledButton(onPressed:()=>setState(()=>step++),child:Text(context.t('continue')))
        else AsyncAction(label:context.t(widget.edit?'save':'start_eatme'),action:() async {
          if(!adult||name.text.trim().isEmpty) {setState(()=>step=0);throw const ApiFailure('invalid_profile');}
          if((allergies.isNotEmpty||intolerances.isNotEmpty)&&!consent) throw const ApiFailure('health_consent_required');
          final data=<String,dynamic>{'name':name.text.trim(),'adult_confirmed':adult,'household_size':size,'timezone':timezone.text.trim(),
            'diets':selected.map((id)=>{'diet_id':id,'strictness':strictness}).toList(),'allergies':allergies.toList(),'intolerances':intolerances.toList(),
            if(consent) 'health_consent_version':'nutrition-profile-1',
            if(medicalConsent) 'medical_consent_version':'medical-nutrition-1',
            if(widget.edit) 'expected_version':state.profile['version']};
          await mutation.send(ref.read(apiProvider),'PUT','/profile',data);
          await ref.read(appProvider.notifier).hydrate();
          if(widget.edit&&context.mounted) Navigator.of(context).pop();
        }),
      ]));
  }
}
