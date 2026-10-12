package com.sao.agent;

import com.sao.engine.SAOWindowPaneDefinitions;
import java.lang.instrument.Instrumentation;
import net.bytebuddy.agent.builder.AgentBuilder;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.matcher.ElementMatchers;

/** Startup-only registration while native WorldDictionary permits script items. */
public final class SAOWindowPaneDefinitionWeave {
    private SAOWindowPaneDefinitionWeave(){ }
    private static boolean installed;
    public static final class BeforeClose {
        @Advice.OnMethodEnter(suppress=Throwable.class)
        public static void enter(){SAOWindowPaneDefinitions.beforeScriptsLoaded();}
    }
    public static void install(){
        try { install(net.bytebuddy.agent.ByteBuddyAgent.install()); }
        catch(Throwable error){SAOAgent.log("window pane definition weave self-attach unavailable: "+error);}
    }
    public static synchronized void install(Instrumentation instrumentation){
        if(installed)return;
        new AgentBuilder.Default().disableClassFormatChanges()
            .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
            .type(ElementMatchers.named("zombie.world.WorldDictionary"))
            .transform((builder,type,loader,module,domain)->builder.visit(Advice.to(BeforeClose.class)
                .on(ElementMatchers.named("ScriptsLoaded").and(ElementMatchers.isStatic()).and(ElementMatchers.takesArguments(0)))))
            .installOn(instrumentation);
        installed=true;
    }
}
