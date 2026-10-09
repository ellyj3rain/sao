package com.sao.engine;

import java.util.Arrays;
import java.util.IdentityHashMap;
import java.util.Objects;
import se.krka.kahlua.vm.LuaClosure;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.Prototype;

/** Compare executable prototypes, captured callables and scalar captures, excluding debug names.
 * Mutable table contents are guarded by their source owner. Scalar mutation fails closed.
 */
public final class SAOLuaSourceIdentity {
    private SAOLuaSourceIdentity() { }
    public static boolean same(Object loaded,Object audited) {
        if(!(loaded instanceof LuaClosure a)||!(audited instanceof LuaClosure b))return false;
        try {return closure(a,b,new IdentityHashMap<>(),new int[]{4096});}
        catch(Throwable unavailable){return false;}
    }
    public static boolean usesEnvironment(Object loaded,Object expected){
        if(!(loaded instanceof LuaClosure a)||!(expected instanceof KahluaTable env))return false;
        try{return environment(a,env,new IdentityHashMap<>(),new int[]{4096});}
        catch(Throwable unavailable){return false;}
    }
    private static boolean environment(LuaClosure a,KahluaTable env,
            IdentityHashMap<LuaClosure,Boolean> seen,int[] budget){
        if(seen.put(a,Boolean.TRUE)!=null)return true;
        if(--budget[0]<0||a.env!=env)return false;
        for(var upvalue:a.upvalues)if(upvalue!=null&&upvalue.getValue() instanceof LuaClosure helper
            &&!environment(helper,env,seen,budget))return false;
        return true;
    }
    private static boolean closure(LuaClosure a,LuaClosure b,
            IdentityHashMap<LuaClosure,LuaClosure> seen,int[] budget){
        LuaClosure prior=seen.get(a);if(prior!=null)return prior==b;
        if(--budget[0]<0||!prototype(a.prototype,b.prototype,0,budget)
            ||a.upvalues.length!=b.upvalues.length)return false;
        seen.put(a,b);
        for(int n=0;n<a.upvalues.length;n++){
            Object av=a.upvalues[n]==null?null:a.upvalues[n].getValue();
            Object bv=b.upvalues[n]==null?null:b.upvalues[n].getValue();
            if(av instanceof LuaClosure ac){if(!(bv instanceof LuaClosure bc)||!closure(ac,bc,seen,budget))return false;}
            else if(bv instanceof LuaClosure)return false;
            else if(av instanceof JavaFunction||bv instanceof JavaFunction){if(av!=bv)return false;}
            else if(av==null||bv==null||av instanceof String||bv instanceof String
                ||av instanceof Number||bv instanceof Number||av instanceof Boolean||bv instanceof Boolean){
                if(!Objects.equals(av,bv))return false;
            }
        }
        return true;
    }
    private static boolean prototype(Prototype a,Prototype b,int depth,int[] budget){
        if(a==null||b==null||depth>64||--budget[0]<0||a.numParams!=b.numParams
            ||a.isVararg!=b.isVararg||a.numUpvalues!=b.numUpvalues
            ||a.maxStacksize!=b.maxStacksize||!Arrays.equals(a.code,b.code)
            ||a.constants.length!=b.constants.length||a.prototypes.length!=b.prototypes.length)return false;
        for(int n=0;n<a.constants.length;n++)if(!Objects.equals(a.constants[n],b.constants[n]))return false;
        for(int n=0;n<a.prototypes.length;n++)if(!prototype(a.prototypes[n],b.prototypes[n],depth+1,budget))return false;
        return true;
    }
}
