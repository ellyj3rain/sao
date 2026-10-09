package com.sao.engine;

import java.util.HashSet;
import java.util.Set;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.LuaClosure;
import zombie.Lua.LuaManager;
import zombie.network.GameClient;
import zombie.network.GameServer;

/** Source-owned type requirements. Personal context and exact transfer remain Lua owners. */
public final class SAOLeisureMaterials {
    private static final String[] OWNERS={"LeisureArt","LeisureMusic","LeisureGames","LeisureRadio","LeisureLifestyle"};
    private static final ThreadLocal<Boolean> QUERYING=ThreadLocal.withInitial(()->false);
    private static final Set<String> FIELDS=Set.of("owner","family","activity","sourceId","revision",
        "requirementId","itemType","role");
    private static final Set<String> TYPE_FIELDS=Set.of("carrier","instrumentType");
    private SAOLeisureMaterials() { }
    private static String scalar(KahluaTable row,String key) {
        Object value=row.rawget(key);
        return value instanceof String text&&!text.isBlank()&&text.length()<=256?text:null;
    }
    private static int append(KahluaTable into,KahluaTable from,String itemType,String owner,int count,Set<String> seen) {
        for(int n=1;n<=from.len();n++) {
            if(!(from.rawget((double)n) instanceof KahluaTable candidate))continue;
            if(!owner.equals(scalar(candidate,"owner"))||!itemType.equals(scalar(candidate,"itemType")))continue;
            boolean valid=true;
            for(String field:FIELDS)if(scalar(candidate,field)==null){valid=false;break;}
            String role=scalar(candidate,"role"),revision=scalar(candidate,"revision");
            if(!valid||!("playable-item".equals(role)||"material".equals(role))
                ||!revision.matches("[a-f0-9]{64}"))continue;
            String key=owner+"|"+candidate.rawget("requirementId")+"|"+candidate.rawget("activity");
            if(!seen.add(key))continue;
            var row=LuaManager.platform.newTable();
            for(String field:FIELDS)row.rawset(field,candidate.rawget(field));
            for(String field:TYPE_FIELDS) {
                String value=scalar(candidate,field);
                if(value!=null)row.rawset(field,value);
            }
            into.rawset((double)++count,row);
        }
        return count;
    }
    public static KahluaTable requirements(SAOIsoPlayerShell body,String itemType) {
        if(GameClient.client||GameServer.server||itemType==null||itemType.isBlank()||itemType.length()>160
            ||body!=null&&SAOConceptObservation.actor(body)==null||LuaManager.platform==null||QUERYING.get())return null;
        var definition=zombie.scripting.ScriptManager.instance.getItem(itemType);
        if(definition==null||!itemType.equals(definition.getFullName()))return null;
        var rows=LuaManager.platform.newTable();var seen=new HashSet<String>();
        QUERYING.set(true);
        try {
            int count=append(rows,SAOTabletop.requirements(itemType),itemType,"SAO.LeisureGames",0,seen);
            if(LuaManager.env==null||!(LuaManager.env.rawget("SAO") instanceof KahluaTable sao)
                ||LuaManager.thread==null||LuaManager.caller==null)return rows;
            for(String name:OWNERS) {
                if(!(sao.rawget(name) instanceof KahluaTable owner)
                    ||!(owner.rawget("materialRequirementsForType") instanceof LuaClosure query))continue;
                Object[] result=LuaManager.caller.pcall(LuaManager.thread,query,body,itemType);
                if(result.length>1&&Boolean.TRUE.equals(result[0])&&result[1] instanceof KahluaTable admitted)
                    count=append(rows,admitted,itemType,"SAO."+name,count,seen);
            }
            return rows;
        }catch(Throwable unavailable){return rows;}
        finally{QUERYING.remove();}
    }
    static boolean recognizes(String itemType) {
        KahluaTable rows=requirements(null,itemType);
        return rows!=null&&rows.len()>0;
    }
}
