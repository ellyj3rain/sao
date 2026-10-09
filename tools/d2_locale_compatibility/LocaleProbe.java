import java.lang.reflect.*;
import java.nio.file.*;
import java.io.*;
import java.util.*;
import java.util.function.Function;
import zombie.core.Translator;
import zombie.core.Language;
import zombie.characters.skills.PerkFactory;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;

/** Installed native JSON loader/getText plus full source callback; no game/render. */
public final class LocaleProbe {
    static int checks;
    static void check(boolean ok, String name) {
        if (!ok) throw new AssertionError("D2_LOCALE:" + name);
        checks++;
    }
    @SuppressWarnings("unchecked")
    public static void main(String[] args) throws Exception {
        var constructor = Language.class.getDeclaredConstructor(String.class,String.class,String.class,boolean.class);
        constructor.setAccessible(true);
        var english = constructor.newInstance("EN","English",null,false);
        Translator.language = english;
        var loader = Translator.class.getDeclaredMethod("tryFillMapFromFile",String.class,String.class,Map.class,Language.class,Function.class);
        loader.setAccessible(true);
        String[][] categories = {{"ContextMenu","contextMenu"},{"Tooltip","tooltip"},{"IG_UI","igui"}};
        for (var pair:categories) {
            var field = Translator.class.getDeclaredField(pair[1]); field.setAccessible(true);
            var map = (Map<String,String>)field.get(null); map.clear();
            loader.invoke(null,args[0],pair[0],map,english,Function.identity());
            loader.invoke(null,args[1],pair[0],map,english,Function.identity());
        }
        for(String row:Files.readAllLines(Path.of(args[2]))) {
            String[] values = row.split("\t",2);
            check(values[1].equals(Translator.getText(values[0])),"native_context_label_"+values[0]);
        }
        check("Welding".equals(Translator.getText("IGUI_perks_MetalWelding")),"actual_native_welding_key");
        check(Translator.getTextOrNull("IGUI_perks_Metalworking")==null,"removed_native_key_not_aliased");
        check(PerkFactory.Perks.MetalWelding != null,"actual_native_welding_perk");
        var platform=J2SEPlatform.getInstance(); var env=platform.newEnvironment(); var thread=new KahluaThread(platform,env);
        thread.debugOwnerThread=Thread.currentThread();
        env.rawset("__nativeWeld",PerkFactory.Perks.MetalWelding);
        env.rawset("getText",(JavaFunction)(frame,count)->frame.push(Translator.getText((String)frame.get(0))));
        for(int i=3;i<args.length;i++) {
            try(var input=Files.newBufferedReader(Path.of(args[i]))) {
                thread.call(LuaCompiler.loadis(input,args[i],env),null,null,null);
            }
        }
        check(Boolean.TRUE.equals(env.rawget("SOURCE_CALL_PROVEN")),"actual_original_radio_callback");
        System.out.println("PASS native locale "+checks);
    }
}
