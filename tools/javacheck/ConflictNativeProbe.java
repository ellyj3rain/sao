import com.sao.bridge.SAOBridge;
import com.sao.engine.*;
import java.nio.file.*;
import java.util.regex.Pattern;
import zombie.characters.*;
import zombie.iso.*;
import zombie.iso.SpriteDetails.IsoFlagType;
import zombie.inventory.*;
import zombie.inventory.types.HandWeapon;
import zombie.scripting.*;
import zombie.scripting.objects.*;
import zombie.world.*;

/** Installed bodies, scanner, LOS, items and native pressedAttack in a controlled cell.
 * Lifecycle controls inject native state/animation ownership; they do not claim a rendered collision. */
public final class ConflictNativeProbe {
    static int checks;
    static zombie.core.skinnedmodel.model.SkinningData skin;
    static final SAOBridge bridge = SAOBridge.INSTANCE;
    static void check(String name, boolean value) {
        if (!value) throw new AssertionError("CONFLICT:" + name);
        checks++; System.out.println("CHECK " + name);
    }
    static Object fixture(String name, Class<?>[] types, Object... args) throws Exception {
        var method = MovementCrossingProbe.class.getDeclaredMethod(name, types);
        method.setAccessible(true); return method.invoke(null, args);
    }
    static void position(IsoGameCharacter body, IsoCell cell, float x, float y) {
        if(body.getCurrentSquare()!=null) body.getCurrentSquare().getMovingObjects().remove(body);
        body.setX(x); body.setY(y); body.setZ(0);
        body.setCurrent(cell.getGridSquare((int)x,(int)y,0)); body.setSquare(body.getCurrentSquare());
        body.getCurrentSquare().getMovingObjects().add(body);
    }
    static SAOIsoPlayerShell person(IsoCell cell, String id) throws Exception {
        var body=(SAOIsoPlayerShell)fixture("person", new Class<?>[]{IsoCell.class},cell);
        OrientationProbe.animation(body,skin);
        body.setNpc(true); body.getModData().rawset("SAOPersonId",id);
        position(body,cell,10.5f,20.5f); cell.getObjectList().add(body); body.setForwardDirection(1,0);
        return body;
    }
    static IsoZombie zombie(IsoCell cell,float x,float y) throws Exception {
        var body=new IsoZombie(cell); body.setHealth(1); position(body,cell,x,y);
        var donor=person(cell,"animation-donor");
        OrientationProbe.field(IsoGameCharacter.class,"animPlayer").set(body,donor.getAnimationPlayer());
        cell.getObjectList().remove(donor);donor.getCurrentSquare().getMovingObjects().remove(donor);
        cell.getZombieList().add(body); cell.getObjectList().add(body); return body;
    }
    static String observe(SAOIsoPlayerShell observer) {
        String rows=SAOPerceptionScanner.scan(observer,"");
        var match=Pattern.compile(":track:([^:|]+)").matcher(rows);
        if(!match.find()) throw new AssertionError("CONFLICT:fixture_observed_zombie " + rows);
        return match.group(1);
    }
    static String opportunity(SAOIsoPlayerShell body,String key) { return bridge.combatOpportunity(body,"zombie",key); }
    static final class Info extends ItemInfo {
        Info(Item item,short id) { name=item.getName();moduleName="Base";fullType="Base."+name;
            registryId=id;isLoaded=true;scriptItem=item;entityScript=item;modId="pz-vanilla"; }
    }
    static final class Dictionary extends DictionaryData {
        void register(Item item,short id) { var info=new Info(item,id);itemIdToInfoMap.put(id,info);itemTypeToInfoMap.put(info.getFullType(),info); }
    }
    static void definitions(Path game) throws Exception {
        var dictionary=new Dictionary(); var data=WorldDictionary.class.getDeclaredField("data");
        data.setAccessible(true);data.set(null,dictionary);
        var module=new ScriptModule();module.name="Base";ScriptManager.instance.moduleMap.put("Base",module);
        String text=ScriptParser.stripComments(Files.readString(game.resolve("media/scripts/generated/items/weapon.txt")));
        short id=2800;
        for(String name:new String[]{"BareHands","Wrench","Pistol"}) {
            var match=Pattern.compile("\\bitem\\s+"+name+"\\s*\\{").matcher(text);
            if(!match.find())throw new AssertionError("missing installed weapon " + name);
            int end=match.end(),depth=1;while(depth>0){char c=text.charAt(end++);if(c=='{')depth++;else if(c=='}')depth--;}
            var item=new Item();item.setModule(module);item.setName(name);item.Load(name,text.substring(match.start(),end));
            item.setRegistry_id(id);module.items.getScriptMap().put(name,item);dictionary.register(item,id++);
        }
    }
    static HandWeapon weapon(String name) { return (HandWeapon)InventoryItemFactory.CreateItem("Base."+name); }
    static void wall(IsoGridSquare right, IsoGridSquare left, boolean enabled) {
        if(enabled){right.getProperties().set(IsoFlagType.collideW);right.getProperties().set(IsoFlagType.cutW);}
        else {right.getProperties().unset(IsoFlagType.collideW);right.getProperties().unset(IsoFlagType.cutW);}
        right.ReCalculateVisionBlocked(left);left.ReCalculateVisionBlocked(right);
    }
    static void nativeState(SAOIsoPlayerShell body,zombie.ai.State state) throws Exception {
        fixture("state",new Class<?>[]{SAOIsoPlayerShell.class,zombie.ai.State.class},body,state);
    }
    public static void main(String[] args) throws Exception {
        var cell=(IsoCell)fixture("boot",new Class<?>[0]);definitions(Path.of(args[0]));
        skin=OrientationProbe.skeleton(Path.of(args[0]));
        for(int x=8;x<=16;x++)for(int y=17;y<=24;y++)cell.getGridSquare(x,y,0).setSolidFloor(true);
        zombie.Lua.LuaManager.env=zombie.Lua.LuaManager.platform.newEnvironment();
        zombie.Lua.LuaManager.thread=new se.krka.kahlua.vm.KahluaThread(zombie.Lua.LuaManager.platform,zombie.Lua.LuaManager.env);
        zombie.Lua.LuaManager.thread.debugOwnerThread=Thread.currentThread();
        zombie.Lua.LuaManager.caller=new se.krka.kahlua.integration.LuaCaller(zombie.Lua.LuaManager.converterManager);
        zombie.Lua.LuaEventManager.register(zombie.Lua.LuaManager.platform,zombie.Lua.LuaManager.env);
        SurvivorFactory.addMaleForename("FixtureMan");SurvivorFactory.addFemaleForename("FixtureWoman");SurvivorFactory.addSurname("FixtureName");
        var observer=person(cell,"observer");var target=zombie(cell,11.2f,20.5f);
        check("no_observation_no_target",opportunity(observer,"invented").startsWith("REFUSED"));
        String key=observe(observer);
        System.out.println("OPPORTUNITY " + opportunity(observer,key));
        check("ordinary_tokenless_unarmed_shove",observer.getModData().rawget("SAOExternalToken")==null
            && opportunity(observer,key).startsWith("AVAILABLE\tshove\t"));
        var second=person(cell,"second");String secondKey=observe(second);
        check("observer_private_token",!key.equals(secondKey)&&opportunity(second,key).startsWith("REFUSED"));
        position(second,cell,9.5f,22.5f);
        observer.getModData().rawset("SAOExternalOwner","foreign");
        check("foreign_body_refused",opportunity(observer,key).startsWith("REFUSED"));
        observer.getModData().rawset("SAOExternalOwner",null);
        IsoPlayer.players[0]=observer;
        check("slotted_body_refused",opportunity(observer,key).startsWith("REFUSED"));IsoPlayer.players[0]=null;
        wall(cell.getGridSquare(11,20,0),observer.getCurrentSquare(),true);
        check("fresh_observation_resolver_sight",SAOPerceptionScanner.observedCombatTarget(observer,"zombie",key)==null);
        check("observed_then_occluded_refused",opportunity(observer,key).startsWith("REFUSED"));
        check("blocked_local_move_withheld",!bridge.localCombatMoves(observer).contains("MOVE\t11.5\t20.5\t0"));
        wall(cell.getGridSquare(11,20,0),observer.getCurrentSquare(),false);
        target.setZ(1);check("target_floor_refused",opportunity(observer,key).startsWith("REFUSED"));target.setZ(0);
        position(target,cell,13.5f,20.5f);
        check("unarmed_out_of_range",opportunity(observer,key).startsWith("REFUSED"));
        position(target,cell,11.2f,20.5f);
        target.setUseless(true);check("deactivated_target_refused",opportunity(observer,key).startsWith("REFUSED"));target.setUseless(false);
        check("missing_native_body_refused",bridge.combatOpportunity(null,"zombie",key).startsWith("REFUSED"));
        String moves=bridge.localCombatMoves(observer);
        System.out.println("MOVES " + moves);
        check("moves_bounded_scalar",!moves.isEmpty()&&moves.split("\n").length<=8
            &&java.util.Arrays.stream(moves.split("\n")).allMatch(v->v.matches("MOVE\\t[0-9.]+\\t[0-9.]+\\t0")));
        check("occupied_local_move_withheld",!moves.contains("MOVE\t11.5\t20.5\t0"));
        var wrench=weapon("Wrench");observer.getInventory().AddItem(wrench);observer.setPrimaryHandItem(wrench);
        check("held_native_melee_available",opportunity(observer,key).startsWith("AVAILABLE\tmelee\t"));
        check("held_weapon_shove_available",bridge.beginCombatObserved(observer,"zombie",key,"shove").startsWith("COMBAT_STARTED"));
        check("cancel_before_attack",bridge.cancelCombatObserved(observer).equals("COMBAT_CANCELLED")&&!observer.isAttackStarted());
        observer.setPrimaryHandItem(null);bridge.resetCombat(observer);
        check("unarmed_not_ranged",bridge.beginCombatObserved(observer,"zombie",key,"ranged").startsWith("COMBAT_FAILED"));
        var pistol=weapon("Pistol");observer.getInventory().AddItem(pistol);observer.setPrimaryHandItem(pistol);
        position(target,cell,13.5f,20.5f);pistol.setCurrentAmmoCount(4);pistol.setRoundChambered(false);
        check("magazine_not_chamber",opportunity(observer,key).startsWith("REFUSED"));
        pistol.setRoundChambered(true);check("chambered_ranged_available",opportunity(observer,key).startsWith("AVAILABLE\tranged\t"));
        pistol.setJammed(true);check("jammed_refused",opportunity(observer,key).startsWith("REFUSED"));pistol.setJammed(false);
        observer.setPrimaryHandItem(null);position(target,cell,11.2f,20.5f);
        observer.getActionContext().reportEvent("EventClimbFence");
        check("pending_crossing_not_stolen",bridge.beginCombatObserved(observer,"zombie",key,"shove").contains("NATIVE_BODY_BUSY")
            &&observer.getActionContext().hasEventOccurred("EventClimbFence"));observer.getActionContext().clearActionContextEvents();
        observer.getCharacterActions().push(new zombie.characters.CharacterTimedActions.BaseAction(observer));
        check("queued_action_not_stolen",bridge.beginCombatObserved(observer,"zombie",key,"shove").contains("NATIVE_BODY_BUSY")
            &&observer.getCharacterActions().size()==1);observer.getCharacterActions().clear();
        nativeState(observer,zombie.ai.states.PlayerHitReactionState.instance());
        check("native_reaction_not_stolen",bridge.beginCombatObserved(observer,"zombie",key,"shove").contains("NATIVE_BODY_BUSY"));nativeState(observer,null);
        check("actual_callback_patch",com.sao.agent.SAOCombatGate.isPatchReady());
        check("one_cycle_started",bridge.beginCombatObserved(observer,"zombie",key,"shove").startsWith("COMBAT_STARTED"));
        check("successor_cannot_replace",bridge.beginCombatObserved(observer,"zombie",key,"shove").contains("BODY_COMMITTED"));
        observer.setPrimaryHandItem(wrench);
        check("weapon_swap_revalidated",bridge.tickCombat(observer).equals("COMBAT_FAILED ADMISSION_CHANGED"));
        observer.setPrimaryHandItem(null);bridge.resetCombat(observer);
        check("start_shove",bridge.beginCombatObserved(observer,"zombie",key,"shove").startsWith("COMBAT_STARTED"));
        var combatsField=SAOBridge.class.getDeclaredField("combats");combatsField.setAccessible(true);
        var active=(SAOCombat)((java.util.Map<?,?>)combatsField.get(bridge)).get(observer);
        String request=active.tick();System.out.println("NATIVE_REQUEST " + request);
        check("native_unarmed_request",request.equals("COMBAT_PENDING")&&observer.isDoShove()
            && observer.isAttackStarted()&&observer.getPrimaryHandItem()==null);
        check("no_pursuit",observer.getPath2()==null && observer.playerMoveDir.getLength()==0);
        // Native ownership controls retain animation/reaction until its owner exits.
        observer.setPerformingShoveAnimation(true);
        check("cancel_holds_native_animation",bridge.cancelCombatObserved(observer).equals("COMBAT_HELD")&&observer.isDoShove());
        check("reset_holds_native_animation",bridge.resetCombat(observer).equals("COMBAT_HELD"));
        observer.setPerformingShoveAnimation(false);
        nativeState(observer,zombie.ai.states.PlayerHitReactionState.instance());
        check("cancel_holds_reaction",bridge.tickCombat(observer).equals("COMBAT_HELD"));nativeState(observer,null);
        check("cancel_after_native_exit",bridge.tickCombat(observer).equals("COMBAT_CANCELLED")&&!observer.isAttackStarted());
        bridge.resetCombat(observer);
        check("second_start",bridge.beginCombatObserved(observer,"zombie",key,"shove").startsWith("COMBAT_STARTED"));
        check("second_native_request",bridge.tickCombat(observer).equals("COMBAT_PENDING"));
        observer.setPerformingShoveAnimation(true);check("cycle_owned",bridge.tickCombat(observer).equals("COMBAT_HELD"));
        target.setHealth(.3f);observer.setPerformingShoveAnimation(false);
        String completed=bridge.tickCombat(observer);
        check("completion_not_damage_credit",completed.equals("COMBAT_COMPLETED attempt=1 outcome=unattributed"));
        check("terminal_no_second_attack",bridge.tickCombat(observer).equals(completed)&&!observer.isAttackStarted());
        bridge.resetCombat(observer);
        check("changed_owner_setup",bridge.beginCombatObserved(observer,"zombie",key,"shove").startsWith("COMBAT_STARTED"));
        observer.getModData().rawset("SAOExternalToken","successor");observer.setIsAiming(true);
        observer.getECSComponent(zombie.characters.component.AIComponent.class).getHumanControlVars().aiming=true;
        check("changed_owner_not_cleared",bridge.tickCombat(observer).equals("COMBAT_FAILED BODY_OWNER_CHANGED")&&observer.isAiming());
        bridge.resetCombat(observer);check("stale_reset_not_clear_successor",observer.isAiming());
        observer.setIsAiming(false);observer.getModData().rawset("SAOExternalToken",null);
        observer.getECSComponent(zombie.characters.component.AIComponent.class).getHumanControlVars().aiming=false;
        observer.setAuthorizedHandToHand(false);
        position(target,cell,10.85f,20.5f);target.setOnFloor(true);
        check("unarmed_observed_prone_stomp",opportunity(observer,key).startsWith("AVAILABLE\tstomp\t"));
        position(target,cell,11.2f,20.5f);
        check("stomp_uses_native_close_reach",bridge.beginCombatObserved(observer,"zombie",key,"stomp").startsWith("COMBAT_FAILED"));
        position(target,cell,10.85f,20.5f);target.setOnFloor(false);
        check("standing_target_not_stomp",bridge.beginCombatObserved(observer,"zombie",key,"stomp").startsWith("COMBAT_FAILED"));
        target.setOnFloor(true);
        check("stomp_started",bridge.beginCombatObserved(observer,"zombie",key,"stomp").startsWith("COMBAT_STARTED"));
        String stompRequest=bridge.tickCombat(observer);System.out.println("STOMP_REQUEST " + stompRequest);
        check("native_exact_stomp_request",stompRequest.equals("COMBAT_PENDING")&&observer.isDoStomp()&&observer.targetOnGround==target);
        observer.setPerformingStompAnimation(true);
        check("stomp_cancellation_waits",bridge.cancelCombatObserved(observer).equals("COMBAT_HELD"));
        observer.setPerformingStompAnimation(false);
        check("stomp_cancel_returns_body",bridge.tickCombat(observer).equals("COMBAT_CANCELLED"));bridge.resetCombat(observer);
        position(target,cell,10.95f,20.5f);
        var intervening=zombie(cell,10.65f,20.5f);intervening.setOnFloor(true);
        check("competing_prone_setup",bridge.beginCombatObserved(observer,"zombie",key,"stomp").startsWith("COMBAT_STARTED"));
        String different=bridge.tickCombat(observer);System.out.println("COMPETING_STOMP " + different);
        check("stomp_exact_native_target",different.equals("COMBAT_FAILED NATIVE_STOMP_TARGET_NOT_ADMITTED")&&!observer.isAttackStarted());
        bridge.resetCombat(observer);cell.getZombieList().remove(intervening);cell.getObjectList().remove(intervening);
        intervening.getCurrentSquare().getMovingObjects().remove(intervening);
        target.setOnFloor(false);position(target,cell,11.2f,20.5f);
        second.getDescriptor().setForename("Observed");second.getDescriptor().setSurname("Person");
        SAOPerceptionScanner.scan(observer,"");
        check("observed_person_exact_name",SAOPerceptionScanner.observedCombatTarget(observer,"person","Observed Person")==second);
        check("native_person_permission_preserved",bridge.combatOpportunity(observer,"person","Observed Person").equals("REFUSED\tnative-pvp"));
        var sameName=person(cell,"duplicate");position(sameName,cell,11.5f,21.5f);
        sameName.getDescriptor().setForename("Observed");sameName.getDescriptor().setSurname("Person");SAOPerceptionScanner.scan(observer,"");
        check("ambiguous_person_not_substituted",SAOPerceptionScanner.observedCombatTarget(observer,"person","Observed Person")==null);
        SAOPerceptionScanner.resetRuntimeForWorld();
        check("world_reset_revokes_targets",opportunity(observer,key).startsWith("REFUSED"));
        System.out.println("PASS conflict native checks="+checks);
    }
}
