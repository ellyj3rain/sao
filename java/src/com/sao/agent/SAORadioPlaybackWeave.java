package com.sao.agent;

import com.sao.engine.SAORadioPlayback;
import java.lang.instrument.Instrumentation;
import java.util.Set;
import net.bytebuddy.agent.ByteBuddyAgent;
import net.bytebuddy.agent.builder.AgentBuilder;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.matcher.ElementMatchers;

/** Audited native SP radio occurrences and scoped NPC presentation routing. */
public final class SAORadioPlaybackWeave {
    private SAORadioPlaybackWeave() { }
    private static boolean installed;
    private static String failure;
    private static Instrumentation nativeInstrumentation;
    private static final Set<String> TARGETS=Set.of("zombie.inventory.types.Radio",
        "zombie.iso.objects.IsoWaveSignal","zombie.vehicles.VehiclePart",
        "zombie.radio.devices.WaveSignalDevice","zombie.radio.ZomboidRadio",
        "zombie.Lua.LuaEventManager","zombie.chat.ChatManager");
    private static final Set<String> TRANSFORMED=java.util.concurrent.ConcurrentHashMap.newKeySet();
    public static final class Text {
        @Advice.OnMethodEnter
        public static SAORadioPlayback.TextCall enter(@Advice.This Object parent,@Advice.AllArguments Object[] args){
            return SAORadioPlayback.enterText(parent,args);
        }
        @Advice.OnMethodExit(onThrowable=Throwable.class)
        public static void exit(@Advice.Enter SAORadioPlayback.TextCall call,@Advice.Thrown Throwable failure){
            SAORadioPlayback.exitText(call,failure);
        }
    }
    public static final class PortableUpdate {
        @Advice.OnMethodEnter(skipOn=Advice.OnNonDefaultValue.class)
        public static boolean enter(@Advice.This Object radio){return SAORadioPlayback.updatePortable(radio);}
    }
    public static final class Distribution {
        @Advice.OnMethodExit
        public static void exit(@Advice.This Object radio,@Advice.AllArguments Object[] args){
            SAORadioPlayback.distribute(radio,args);
        }
    }
    public static final class PrivateEvent {
        @Advice.OnMethodEnter(skipOn=Advice.OnNonDefaultValue.class)
        public static boolean enter(@Advice.Argument(0) String name,@Advice.Argument(7) Object parent){
            return SAORadioPlayback.privatePortableEvent(name,parent);
        }
    }
    public static final class PrivateChat {
        @Advice.OnMethodEnter(skipOn=Advice.OnNonDefaultValue.class)
        public static boolean enter(){return SAORadioPlayback.privateChat();}
    }
    public static synchronized void install(){
        if(installed)return;
        try {install(ByteBuddyAgent.install());}
        catch(Throwable error){failure=String.valueOf(error);SAOAgent.log("radio playback attach refused: "+error);}
    }
    public static synchronized void install(Instrumentation instrumentation){
        if(installed)return;
        try {
            new AgentBuilder.Default().disableClassFormatChanges()
                .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
                .with(new AgentBuilder.Listener.Adapter(){
                    @Override public void onTransformation(net.bytebuddy.description.type.TypeDescription type,
                        ClassLoader loader,net.bytebuddy.utility.JavaModule module,boolean loaded,
                        net.bytebuddy.dynamic.DynamicType dynamicType){TRANSFORMED.add(type.getName());}
                    @Override public void onError(String name,ClassLoader loader,
                        net.bytebuddy.utility.JavaModule module,boolean loaded,Throwable error){
                        if(TARGETS.contains(name)){failure=name+":"+error;SAOAgent.log("radio playback transform refused: "+failure);}
                    }
                })
                .type(ElementMatchers.namedOneOf(TARGETS.toArray(String[]::new)))
                .transform((builder,type,loader,module,domain)->{
                    String name=type.getName();
                    if(name.equals("zombie.inventory.types.Radio"))return builder
                        .visit(Advice.to(Text.class).on(ElementMatchers.named("AddDeviceText")
                            .and(ElementMatchers.takesArguments(String.class,float.class,float.class,float.class,String.class,String.class,int.class))))
                        .visit(Advice.to(PortableUpdate.class).on(ElementMatchers.named("update").and(ElementMatchers.takesArguments(0))));
                    if(name.equals("zombie.iso.objects.IsoWaveSignal"))return builder.visit(Advice.to(Text.class)
                        .on(ElementMatchers.named("AddDeviceText").and(ElementMatchers.takesArguments(
                            String.class,float.class,float.class,float.class,String.class,String.class,int.class,boolean.class))));
                    if(name.equals("zombie.vehicles.VehiclePart"))return builder.visit(Advice.to(Text.class)
                        .on(ElementMatchers.named("AddDeviceText").and(ElementMatchers.takesArguments(
                            String.class,float.class,float.class,float.class,String.class,String.class,int.class))));
                    if(name.equals("zombie.radio.devices.WaveSignalDevice"))return builder.visit(Advice.to(Text.class)
                        .on(ElementMatchers.named("AddDeviceText").and(ElementMatchers.takesArguments(
                            zombie.characters.IsoPlayer.class,String.class,float.class,float.class,float.class,String.class,String.class,int.class))));
                    if(name.equals("zombie.radio.ZomboidRadio"))return builder.visit(Advice.to(Distribution.class)
                        .on(ElementMatchers.named("DistributeTransmission").and(ElementMatchers.takesArguments(
                            int.class,int.class,int.class,String.class,String.class,String.class,float.class,float.class,float.class,int.class,boolean.class))));
                    if(name.equals("zombie.Lua.LuaEventManager"))return builder.visit(Advice.to(PrivateEvent.class)
                        .on(ElementMatchers.named("triggerEvent").and(ElementMatchers.takesArguments(
                            String.class,Object.class,Object.class,Object.class,Object.class,Object.class,Object.class,Object.class))));
                    return builder.visit(Advice.to(PrivateChat.class).on(ElementMatchers.named("showRadioMessage")
                        .or(ElementMatchers.named("showStaticRadioSound"))));
                }).installOn(instrumentation);
            installed=true;
            nativeInstrumentation=instrumentation;
            for(Class<?> type:instrumentation.getAllLoadedClasses()){
                if(TARGETS.contains(type.getName())&&instrumentation.isModifiableClass(type))instrumentation.retransformClasses(type);
            }
            SAOAgent.log("radio playback weave installed "+report());
        }catch(Throwable error){failure=String.valueOf(error);SAOAgent.log("radio playback install refused: "+error);}
    }
    public static synchronized boolean ready(){
        install();if(!installed||failure!=null)return false;
        try {
            for(String name:TARGETS){
                Class<?> type=Class.forName(name,false,SAORadioPlaybackWeave.class.getClassLoader());
                if(!TRANSFORMED.contains(name)){
                    if(!nativeInstrumentation.isModifiableClass(type))return false;
                    nativeInstrumentation.retransformClasses(type);
                }
                if(!TRANSFORMED.contains(name))return false;
            }
            return failure==null;
        }catch(Throwable error){failure=String.valueOf(error);return false;}
    }
    public static String report(){return failure!=null?"failed:"+failure:installed
        ?"installed;transformed="+TRANSFORMED:"not-installed";}
}
