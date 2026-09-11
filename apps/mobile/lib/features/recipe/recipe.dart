import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';

class RecipePage extends ConsumerStatefulWidget {
  const RecipePage({super.key,required this.recipeId});
  final String recipeId;
  @override
  ConsumerState<RecipePage> createState()=>_RecipePageState();
}
class _RecipePageState extends ConsumerState<RecipePage> {
  late int servings=ref.read(appProvider).profile['household_size'] as int? ?? 1;
  late Future<(Recipe,Json)> future=load();
  String tab='ingredients';
  Future<(Recipe,Json)> load() async {
    final api=ref.read(apiProvider);
    final recipe=await api.request('GET','/recipes/${widget.recipeId}');
    final preview=await api.request('POST','/cooking/preview',body:{'recipe_id':widget.recipeId,'servings':servings});
    return (Recipe.fromJson(recipe),preview);
  }
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(),body:FutureBuilder<(Recipe,Json)>(future:future,builder:(context,snapshot){
    if(snapshot.hasError) return PageBody(children:[StatusNote(text:context.t(snapshot.error is ApiFailure?(snapshot.error as ApiFailure).code:'unknown_error'),warning:true),
      FilledButton(onPressed:()=>setState(()=>future=load()),child:Text(context.t('retry')))]);
    if(!snapshot.hasData) return const Center(child:CircularProgressIndicator());
    final (recipe,plan)=snapshot.data!;
    return PageBody(children:[
      Text(localized(recipe.title,context.language),style:Theme.of(context).textTheme.displaySmall),const SizedBox(height:16),
      Text(context.t('minutes',{'minutes':recipe.minutes})),const SizedBox(height:16),
      Row(children:[Text(context.t('servings')),const Spacer(),IconButton(tooltip:context.t('fewer'),onPressed:servings>1?()=>setState((){servings--;future=load();}):null,
        icon:const Icon(Icons.remove)),Text('$servings'),IconButton(tooltip:context.t('more'),onPressed:servings<20?()=>setState((){servings++;future=load();}):null,icon:const Icon(Icons.add))]),
      const SizedBox(height:16),SegmentedButton<String>(segments:['ingredients','overview','why'].map((s)=>ButtonSegment(value:s,label:Text(context.t(s)))).toList(),
        selected:{tab},onSelectionChanged:(s)=>setState(()=>tab=s.first)),const SizedBox(height:20),
      if(tab=='ingredients') for(final item in (plan['ingredients'] as List)) ListTile(contentPadding:EdgeInsets.zero,
        title:Text(localized(Map<String,dynamic>.from(item['food']['name'] as Map),context.language)),
        subtitle:Text(context.t('required_available',{'required':item['quantity'] as String,'available':item['available'] as String,'unit':item['food']['unit'] as String}))),
      if(tab=='overview') for(final (index,instruction) in recipe.instructions(context.language).indexed)
        Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text('${index+1}. $instruction',style:Theme.of(context).textTheme.bodyLarge)),
      if(tab=='why') ...[
        StatusNote(text:context.t('validation_explanation')),
        for(final diet in ref.read(appProvider).diets.where((d)=>(plan['diet_rules_version'] as Map).containsKey(d.id)))
          ListTile(contentPadding:EdgeInsets.zero,title:Text(localized(diet.name,context.language)),
            subtitle:Text(context.t('rule_version',{'version':(plan['diet_rules_version'] as Map)[diet.id] as int}))),
        StatusNote(text:context.t('demo_data_not_a_safety_guarantee')),
      ],
      const SizedBox(height:12),ExpansionTile(tilePadding:EdgeInsets.zero,title:Text(context.t('nutrition')),children:[StatusNote(text:context.t('nutrition_unavailable'))]),
      if((plan['shortages'] as List).isNotEmpty) StatusNote(text:context.t('missing_ingredients_notice')),
      const SizedBox(height:24),FilledButton(onPressed:ref.watch(appProvider).offline?null:()=>context.push('/cook/${recipe.id}?servings=$servings'),
        child:Text(context.t('start_cooking'))),
    ]);
  }));
}
