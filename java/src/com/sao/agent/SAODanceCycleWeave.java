package com.sao.agent;

import com.sao.engine.SAODanceCycle;
import java.lang.instrument.Instrumentation;
import net.bytebuddy.agent.ByteBuddyAgent;
import net.bytebuddy.agent.builder.AgentBuilder;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.matcher.ElementMatchers;

/** Exact native perform scope preserves witnessed loops across BaseAction animation cleanup. */
public final class SAODanceCycleWeave {
    private SAODanceCycleWeave() { }
    private static volatile boolean installed,transformed;
    private static volatile String failure;
    private static final String TARGET="zombie.characters.CharacterTimedActions.LuaTimedActionNew";
    public static final class Perform {
        @Advice.OnMethodEnter(suppress=Throwable.class)
        public static SAODanceCycle.PerformCall enter(@Advice.This Object action){return SAODanceCycle.enterPerform(action);}
        @Advice.OnMethodExit(onThrowable=Throwable.class,suppress=Throwable.class)
        public static void exit(@Advice.Enter SAODanceCycle.PerformCall call){SAODanceCycle.exitPerform(call);}
    }
    public static synchronized void install(){
        if(installed)return;
        try {install(ByteBuddyAgent.install());}
        catch(Throwable error){failure=String.valueOf(error);SAOAgent.log("dance cycle attach refused: "+error);}
    }
    public static synchronized void install(Instrumentation instrumentation){
        if(installed)return;
        try {
            new AgentBuilder.Default().disableClassFormatChanges()
                .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
                .with(new AgentBuilder.Listener.Adapter(){
                    @Override public void onTransformation(net.bytebuddy.description.type.TypeDescription type,
                        ClassLoader loader,net.bytebuddy.utility.JavaModule module,boolean loaded,
                        net.bytebuddy.dynamic.DynamicType dynamicType){if(TARGET.equals(type.getName()))transformed=true;}
                    @Override public void onError(String name,ClassLoader loader,
                        net.bytebuddy.utility.JavaModule module,boolean loaded,Throwable error){
                        if(TARGET.equals(name)){failure=String.valueOf(error);SAOAgent.log("dance cycle transform refused: "+error);}
                    }
                })
                .type(ElementMatchers.named(TARGET))
                .transform((builder,type,loader,module,domain)->builder.visit(Advice.to(Perform.class)
                    .on(ElementMatchers.named("perform").and(ElementMatchers.takesArguments(0)).and(ElementMatchers.returns(void.class)))))
                .installOn(instrumentation);
            installed=true;
        }catch(Throwable error){failure=String.valueOf(error);SAOAgent.log("dance cycle weave refused: "+error);}
    }
    public static boolean ready(){return installed&&transformed&&failure==null;}
}
