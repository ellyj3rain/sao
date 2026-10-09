        for(String name:new String[]{"ISRestAction"}) {
            String key=("media/lua/shared/TimedActions/"+name+".lua").toLowerCase(java.util.Locale.ENGLISH);
            var relative=zombie.ZomboidFileSystem.class.getDeclaredField("relativeMap");relative.setAccessible(true);
            ((java.util.Map<String,String>)relative.get(zombie.ZomboidFileSystem.instance)).put(key,key);
            zombie.ZomboidFileSystem.instance.activeFileMap.put(key,Path.of(args[0],"media/lua/shared/TimedActions/"+name+".lua").toString());
        }
        env.rawset("__tamperRestRejected",(JavaFunction)(frame,count)->{
            String key="media/lua/shared/timedactions/isrestaction.lua";var fs=zombie.ZomboidFileSystem.instance;
            String original=fs.activeFileMap.get(key);
            try{fs.activeFileMap.put(key,args[args.length-1]);return frame.push(com.sao.engine.SAOLeisureActionSource.read("ISRestAction")==null);}
            finally{fs.activeFileMap.put(key,original);}
        });
        var seating=zombie.seating.SeatingManager.getInstance();
        seating.Reset();
        var loaded=new zombie.seating.SeatingData(Path.of(args[0],"media").toString());loaded.init();
        var mergedField=zombie.seating.SeatingManager.class.getDeclaredField("mergedTilesets");mergedField.setAccessible(true);
        var merged=(zombie.seating.SeatingData)mergedField.get(seating);merged.initMerged();
        var merge=zombie.seating.SeatingData.class.getDeclaredMethod("mergeTilesets",zombie.seating.SeatingData.class);merge.setAccessible(true);merge.invoke(merged,loaded);
        var animSet=new zombie.core.skinnedmodel.advancedanimation.AnimationSet();animSet.name="sao-seating-fixture";
        var animState=new zombie.core.skinnedmodel.advancedanimation.AnimState();animState.name="sitonfurniture";animState.set=animSet;
        var clips=new HashMap<String,zombie.core.skinnedmodel.animation.AnimationClip>();
        var indices=new HashMap<String,Integer>();indices.put("Bip01",0);
        for(String side:new String[]{"Front","Left","Right"}) {
            var node=zombie.core.skinnedmodel.advancedanimation.AnimNode.Parse(Path.of(args[0],"media/AnimSets/player/sitonfurniture",side.toLowerCase(java.util.Locale.ENGLISH),"SitOnFurniture"+side+".xml").toString());
            if(node==null)throw new AssertionError("installed seating node absent");
            animState.nodes.add(node);node.parentState=animState;
            var frames=new ArrayList<zombie.core.skinnedmodel.animation.Keyframe>();
            for(int t=0;t<2;t++) {
                var k=new zombie.core.skinnedmodel.animation.Keyframe(new org.lwjgl.util.vector.Vector3f(),new org.lwjgl.util.vector.Quaternion(),new org.lwjgl.util.vector.Vector3f(1,1,1));
                k.bone=0;k.boneName="Bip01";k.time=t;frames.add(k);
            }
            clips.put(node.animName,new zombie.core.skinnedmodel.animation.AnimationClip(1,frames,node.animName,false));
        }
        animSet.states.put("sitonfurniture",animState);
        var setMap=zombie.core.skinnedmodel.advancedanimation.AnimationSet.class.getDeclaredField("setMap");setMap.setAccessible(true);
        ((java.util.Map<String,zombie.core.skinnedmodel.advancedanimation.AnimationSet>)setMap.get(null)).put(animSet.name,animSet);
        var uf=sun.misc.Unsafe.class.getDeclaredField("theUnsafe");uf.setAccessible(true);var unsafe=(sun.misc.Unsafe)uf.get(null);
        var model=(zombie.core.skinnedmodel.model.Model)unsafe.allocateInstance(zombie.core.skinnedmodel.model.Model.class);
        var privateAsset=Class.forName("zombie.asset.Asset$PRIVATE");var assetCtor=privateAsset.getDeclaredConstructor(zombie.asset.Asset.class);assetCtor.setAccessible(true);
        var assetState=assetCtor.newInstance(model);var currentAssetState=privateAsset.getDeclaredField("currentState");currentAssetState.setAccessible(true);currentAssetState.set(assetState,zombie.asset.Asset.State.READY);
        var assetPrivate=zombie.asset.Asset.class.getDeclaredField("priv");assetPrivate.setAccessible(true);assetPrivate.set(model,assetState);
        model.tag=new zombie.core.skinnedmodel.model.SkinningData(clips,java.util.List.of(new org.lwjgl.util.vector.Matrix4f()),java.util.List.of(new org.lwjgl.util.vector.Matrix4f()),java.util.List.of(new org.lwjgl.util.vector.Matrix4f()),java.util.List.of(-1),indices);
        var modelField=zombie.core.skinnedmodel.animation.AnimationPlayer.class.getDeclaredField("model");modelField.setAccessible(true);
        var nativePlayerField=IsoGameCharacter.class.getDeclaredField("animPlayer");nativePlayerField.setAccessible(true);
        var players=new java.util.IdentityHashMap<SAOIsoPlayerShell,zombie.core.skinnedmodel.animation.AnimationPlayer>();
        for(var b:new SAOIsoPlayerShell[]{body,other}) {var ap=(zombie.core.skinnedmodel.animation.AnimationPlayer)nativePlayerField.get(b);players.put(b,ap);modelField.set(ap,model);b.getAdvancedAnimator().animSet=animSet;}
        zombie.core.skinnedmodel.ModelManager.instance.maleModel=model;zombie.core.skinnedmodel.ModelManager.instance.femaleModel=model;
        var piano=new IsoObject(cell);var pair=new IsoObject(cell);var seat=new IsoObject(cell);var replacement=new IsoObject(cell);
        for(var obj:new IsoObject[]{piano,pair,seat,replacement}) {
            var square=cell.getGridSquare(obj==piano?10:obj==pair?11:10,obj==piano||obj==pair?21:20,0);
            obj.setSquare(square);square.getObjects().add(obj);
            var sprite=new zombie.iso.sprite.IsoSprite();sprite.setName(obj==piano?"recreational_01_8":obj==pair?"recreational_01_9":"furniture_seating_indoor_02_0");
            sprite.tilesetName=obj==piano||obj==pair?"recreational_01":"furniture_seating_indoor_02";sprite.tileSheetIndex=obj==piano?8:obj==pair?9:0;
            obj.setSprite(sprite);
        }
        env.rawset("__piano",piano);env.rawset("__pair",pair);env.rawset("__seat",seat);env.rawset("__replacementSeat",replacement);
        var state=zombie.ai.states.PlayerSitOnFurnitureState.instance();
        env.rawset("__enterSeating",(JavaFunction)(frame,count)->{
            var b=(SAOIsoPlayerShell)frame.get(0);
            if(!b.getActionContext().hasEventOccurred("EventSitOnFurniture"))throw new AssertionError("unissued native furniture event");
            try{var f=zombie.ai.StateMachine.class.getDeclaredField("currentState");f.setAccessible(true);f.set(b.getStateMachine(),state);}catch(Exception e){throw new IllegalStateException(e);}
            state.enter(b);return 0;
        });
        env.rawset("__occupySeat",(JavaFunction)(frame,count)->{
            var b=(SAOIsoPlayerShell)frame.get(0);b.setSitOnFurnitureDirection(zombie.iso.IsoDirections.S);b.setVariable("SitOnFurnitureDirection","Front");state.enter(b);
            var event=new zombie.core.skinnedmodel.advancedanimation.AnimEvent();event.eventName="SitOnFurnitureStarted";state.animEvent(b,null,null,event);state.execute(b);return 0;
        });
        env.rawset("__sitAnimationEnd",(JavaFunction)(frame,count)->{
            var b=(SAOIsoPlayerShell)frame.get(0);var event=new zombie.core.skinnedmodel.advancedanimation.AnimEvent();event.eventName="SitOnFurnitureStarted";state.animEvent(b,null,null,event);return 0;
        });
        env.rawset("__exitSeating",(JavaFunction)(frame,count)->{
            var b=(SAOIsoPlayerShell)frame.get(0);if(b.isSittingOnFurniture()){state.abortSitting(b);state.exit(b);}
            try{var f=IsoGameCharacter.class.getDeclaredField("animPlayer");f.setAccessible(true);f.set(b,players.get(b));}catch(Exception e){throw new IllegalStateException(e);}return 0;
        });
        env.rawset("__settleFacing",(JavaFunction)(frame,count)->{
            var b=(SAOIsoPlayerShell)frame.get(0);var ap=players.get(b);
            try{var f=IsoGameCharacter.class.getDeclaredField("animPlayer");f.setAccessible(true);f.set(b,ap);modelField.set(ap,model);}catch(Exception e){throw new IllegalStateException(e);}
            ap.setAngleToTarget();return 0;
        });
