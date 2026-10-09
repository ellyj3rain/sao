"""Materialize the selected D2 source payloads into SAO without an install fallback.

This importer never edits an existing unowned destination.  Common payloads are
overlaid by the exact native-compatible version; alternative versions are not
imported.  Original Lua remains outside the engine's autoload directories for
the existing private, revision-checked owner environments.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

SOURCES = {
    "LifestyleHobbies": ("3403870858/mods/Lifestyle", "42", "Angry", "C14/DR-034 selected animation grant; broader source terms retained, scope unestablished"),
    "NewMusic": ("3739256725/mods/Talis New Music", "42", "talismon", "No reusable licence declaration found in installed root"),
    "ComputerModkum": ("3725497089/mods/ComputerMod", "42", "Kumeji", "No reusable licence declaration found in installed root"),
    "ProjectArcade": ("3645980077/mods/ProjectArcade", "42.15", "Bass", "No reusable licence declaration found in installed root"),
    "FWOFitnessWorkoutOverhaul": ("2940354599/mods/FWO Fitness Workout Overhaul", "42", "Codename280", "README permits local modification; redistribution requires explicit creator permission"),
    "FWOBenchPressTreadmill": ("2940354599/mods/FWO Treadmill & BenchPress", "42", "Codename280", "README permits local modification; redistribution requires explicit creator permission"),
    "KnoxAquarium": ("3797356103/mods/KnoxAquarium", "42", "RentCollectorClips", "CREDITS.txt retained: CC-BY4 source tank; source-project partner/commercial model and species grants have distinct onward scopes"),
}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def lua_quote(value: str) -> str:
    return json.dumps(value, ensure_ascii=True)


def overlay(root: Path, version: str) -> tuple[dict[str, Path], list[dict]]:
    files: dict[str, Path] = {}
    overrides = []
    for payload in ("common", version):
        media = root / payload / "media"
        if not media.is_dir():
            continue
        for source in sorted(media.rglob("*")):
            if source.is_file():
                relative = "media/" + source.relative_to(media).as_posix()
                prior = files.get(relative)
                if prior:
                    overrides.append({"path": relative, "common": str(prior), "selected": str(source), "equal": sha(prior.read_bytes()) == sha(source.read_bytes())})
                files[relative] = source
    if not files:
        raise ValueError(f"missing selected media: {root} {version}")
    return files, overrides


def adapt_lua(raw: bytes, source_id: str) -> tuple[bytes, list[dict]]:
    text = raw.decode("utf-8-sig")
    changes = []
    for pattern in (
        r"getActivatedMods\(\):contains\(\s*(['\"])(%s)\1\s*\)" % re.escape(source_id),
        r"isModActive\(\s*(['\"])(%s)\1\s*\)" % re.escape(source_id),
    ):
        text, count = re.subn(pattern, lambda m: "SAO.SourceIntegration.active(" + lua_quote(source_id) + ")", text)
        if count:
            changes.append({"kind": "owned-source-availability", "count": count, "pattern": pattern})
    # Source readers in the imported runtime resolve owned originals as well.
    pattern = r"getModFileReader\(\s*(['\"])(%s)\1\s*," % re.escape(source_id)
    text, count = re.subn(pattern, lambda m: "SAO.SourceIntegration.reader(" + lua_quote(source_id) + ",", text)
    if count:
        changes.append({"kind": "owned-source-reader", "count": count})
    if source_id == "NewMusic" and 'pcall(getModFileReader, MOD_ID, path, false)' in text:
        text = text.replace('pcall(getModFileReader, MOD_ID, path, false)', 'pcall(SAO.SourceIntegration.reader, MOD_ID, path, false)')
        changes.append({"kind": "owned-named-source-reader", "count": 1})
    if source_id == "LifestyleHobbies" and 'local contextSRJ = require "Skill Recovery Journal Context"' in text:
        text = text.replace('local contextSRJ = require "Skill Recovery Journal Context"', 'local contextSRJ\nif getActivatedMods():contains("SkillRecoveryJournal") then contextSRJ = require "Skill Recovery Journal Context" end')
        changes.append({"kind": "optional-journal-compatibility-guard", "count": 1})
    if source_id == "ProjectArcade" and 'require "TimedActions/ISWalkToTimedAction"' in text:
        text = text.replace('require "TimedActions/ISWalkToTimedAction"', '-- ISWalkToTimedAction is an installed Build42 native global; no Lua module.')
        changes.append({"kind": "native-build42-walk-action-module-resolution", "count": 1})
    prefix = ('-- Integrated source: ' + source_id + '; original revision and terms in SAOSources manifest.\n'
              'require "SAO_SourceIntegration"\n'
              'if not SAO.SourceIntegration.active(' + lua_quote(source_id) + ') then return end\n')
    return (prefix + text).encode("utf-8"), changes


def adapt_lifestyle_physical_owner(raw: bytes, selected_path: str) -> tuple[bytes, list[dict]]:
    """One exact source-object physical producer; private source bytes remain original."""
    if selected_path not in {"media/lua/client/InteractionRange.lua", "media/lua/client/LSEffectsAux.lua"}:
        return raw, []
    text = raw.decode("utf-8")
    guard = "SAO.LeisureLifestyle and SAO.LeisureLifestyle.physicalSourceOwner and SAO.LeisureLifestyle.physicalSourceOwner(v) == true"
    if selected_path.endswith("InteractionRange.lua"):
        first = '\t\t\tif v:getModData().JukeinRange and (v:getModData().JukeinRange ~= "out of range") and (v:getModData().OnOff == "on") and v:getModData().JukeBckpSquare then'
        last = '\t\t\tend--range'
        assert text.count(first) == 1 and text.count(last) == 1
        text = text.replace(first, '\t\t\tif not (' + guard + ') then\n' + first, 1)
        # Original following presentation/listening branches still run for this player.
        continuation = '\n\t\t\telse\n\t\t\t\tlocal readObject; readObject, Facing, groupName = getObj(v, "Jukebox")\n\t\t\t\tif Facing == "S" then JukeboxLightSprite, JukeboxLightSpritePlay1, JukeboxLightSpritePlay2, JukeboxLightSpritePlayOverlay = "LS_JukeboxLight_4", "LS_JukeboxLight_5", "LS_JukeboxLight_6", "LS_JukeboxLight_7" end\n\t\t\t\tif v:getModData().OnOff == "on" and v:getModData().OnPlay and v:getModData().OnPlay ~= "nothing" and v:getModData().genre ~= "JukeboxAfterTurnOn" and playerIsInRange(playerObj, v, 30) then hasJukeNearby = true end\n\t\t\tend--sao-physical-owner'
        text = text.replace(last, last + continuation, 1)
    else:
        first = '\t\t\t\t\tif v:hasModData() and'
        assert text.count(first) == 1
        text = text.replace(first, '\t\t\t\t\tif not (' + guard + ') and v:hasModData() and', 1)
    return text.encode("utf-8"), [{"kind": "exact-owned-jukebox-physical-producer", "ownerQuery": "SAO.LeisureLifestyle.physicalSourceOwner", "privateOriginalUnchanged": True}]


def adapt_newmusic_track_finished_context(raw, selected_path):
    if selected_path != 'media/lua/client/runtime/NMClientTrackFinishedDispatch.lua': return raw, []
    before = b'    if keep then\n        if NMClientWorldSourceCache and NMClientWorldSourceCache.upsertFromPayload then\n            local source = entry and entry.source or nil\n'
    after = b'    if keep then\n        local source = entry and entry.source or nil\n        if NMClientWorldSourceCache and NMClientWorldSourceCache.upsertFromPayload then\n'
    if raw.count(before) != 1: raise ValueError('NewMusic track-finished source-context anchor changed')
    return raw.replace(before,after,1), [{'kind':'lexical-track-finished-source-context','privateOriginalUnchanged':True,'sourceStateAndIntentUnchanged':True}]


def adapt_newmusic_loot_diagnostic(raw: bytes, selected_path: str) -> tuple[bytes, list[dict]]:
    """Capture the source's own readiness predicate in its earlier diagnostic closure."""
    if selected_path != "media/lua/server/NMServerSandboxLootController.lua":
        return raw, []
    text = raw.decode("utf-8")
    declaration = "local logLootBootstrap\n"
    definition = "local function areDistributionTablesReady()"
    if text.count(declaration) != 1 or text.count(definition) != 1:
        raise ValueError("NewMusic loot diagnostic source anchors changed")
    text = text.replace(declaration, declaration + "local areDistributionTablesReady\n", 1)
    text = text.replace(definition, "areDistributionTablesReady = function()", 1)
    return text.encode("utf-8"), [{"kind": "lexical-loot-bootstrap-readiness", "predicate": "areDistributionTablesReady", "privateOriginalUnchanged": True, "gameplayPredicateUnchanged": True}]


def adapt_lifestyle_utility_bindings(raw: bytes, selected_path: str) -> tuple[bytes, list[dict]]:
    """Preserve supplied capacity and the utility's own retiring callbacks."""
    if selected_path != 'media/lua/shared/LSUtil.lua':
        return raw, []
    changes = [
        (b'if arg[2] then fluidContainer:setCapacity(arg[2]); end',
         b'if args[2] then fluidContainer:setCapacity(args[2]); end'),
        (b'local stopLoopedSounds = function()', b'local function stopLoopedSounds()'),
        (b'local playNextSound = function()', b'local function playNextSound()'),
    ]
    content = raw
    for old, new in changes:
        if content.count(old) != 1:
            raise ValueError('Lifestyle utility source anchor changed: ' + old.decode())
        content = content.replace(old, new, 1)
    return content, [{'kind': 'supplied-fluid-capacity-and-local-sound-callbacks',
                      'argument': 'args', 'callbacks': ['stopLoopedSounds', 'playNextSound'],
                      'privateOriginalUnchanged': True, 'sourceCallbackBodiesUnchanged': True}]


def adapt_lifestyle_invention_bindings(raw: bytes, selected_path: str) -> tuple[bytes, list[dict]]:
    """Three exact source bindings; native effects and original provenance stay owned."""
    changes = {
        'media/lua/shared/Inventions/inventions_func.lua': (
            b'if not character or not character:isEquippedClothing(item) then return; end\r\n\tif data',
            b'if not character or not character:isEquippedClothing(item) then return; end\r\n\tlocal data = item:getModData().movableData\r\n\tif data',
            'neural-hat-item-local-invention-data'),
        'media/lua/shared/TimedActions/LSInvNeuralHatPress.lua': (
            b'LSUtil.playSoundCharacter(character, "Gadget_WOOSH"',
            b'LSUtil.playSoundCharacter(self.character, "Gadget_WOOSH"',
            'neural-hat-action-owned-sound-character'),
        'media/lua/client/Painting/Sculpting/IceObjs.lua': (
            b'\t\tsqr:RemoveTileObject(obj)\r\n', b'\t\tsqr:RemoveTileObject(object)\r\n',
            'ice-sculpture-exact-removal-object'),
    }
    selected = changes.get(selected_path)
    if not selected:
        return raw, []
    old, new, kind = selected
    if raw.count(old) != 1:
        raise ValueError('Lifestyle invention source anchor changed: ' + selected_path)
    return raw.replace(old, new, 1), [{'kind': kind, 'privateOriginalUnchanged': True,
                                      'sourceEffectsAndLifecycleUnchanged': True}]


LIFESTYLE_TEMPORARY_PREIMAGES = {'client/Instruments/VanillaInstrumentsContextMenu.lua': '0fdeaba0d0d2cea63aadcf7fd8a7b8e22855ccc66a960f4b9b5a3a65888423d6', 'client/Instruments/NewInstrumentsContextMenu.lua': 'd01946ef281185886791674902a32b9cf00ac5b88f4da78fba2045c48471fbbf', 'client/DJBoothContextMenu.lua': '5e4cbf82c1befc4570764713b7e9a7cc1aa94bf9ed1e807334d8e4985f20e297', 'shared/TimedActions/PlayerIsDancingToMusic.lua': '81cbd4609365be066b7a1f3c269954d823a28b4a4dd395bfb09bf8c554917f6d', 'server/LSservercommands.lua': '0cde6f2b2132f734c77de85b9d1f63311dfad17df1e4f72b2d628263ed239e3a'}

LIFESTYLE_STATE_LIFETIME_PREIMAGES = {
    'server/LSservercommands.lua': '5e447f4c964cb4d51d595ba8ef9a39917f62e70b2b5160a536d40f34f2c98fb5',
    'client/ISUI/LSMirrorMenu.lua': '3ee729f2e53a784e379d038adc0e82c7997db31f4fcf2dfcd6a1ff5c9e24089d',
    'shared/TimedActions/LSUseTub.lua': 'f7c5e6cd4ccae19a1678d90d0b5c6c68de4d4c9b037d22f03be61a4118c5109f',
}

def adapt_lifestyle_state_lifetimes(raw: bytes, selected_path: str) -> tuple[bytes, list[dict]]:
    path = selected_path.removeprefix('media/lua/')
    if path not in LIFESTYLE_STATE_LIFETIME_PREIMAGES:
        return raw, []
    if sha(raw) != LIFESTYLE_STATE_LIFETIME_PREIMAGES[path]:
        raise ValueError('source lifetime preimage changed: ' + path)
    text = raw.decode('utf-8').replace('\r\n', '\n')
    if path == 'server/LSservercommands.lua':
        start = text.index('\t\t\t\tif JukeboxLightOn ~= nil then')
        end = text.index('\n\t\n--    local emitter', start)
        text = text[:start] + '''-- MainLight is the existing source's transient native handle. Native moddata
-- save omits userdata; a saved overlay alone never proves a current lamp.
local mainLight = Jukebox:getModData().MainLight
local currentLamp = mainLight and mainLight ~= 0 and JukeboxCell:getLamppostPositions():contains(mainLight)
local currentOverlay = getObjFromSqr(Jukebox:getX(), Jukebox:getY(), Jukebox:getZ(), JukeboxLightSprite)
if currentLamp and currentOverlay then return end
if not currentOverlay then
    local JukeboxLight = IsoObject.new(sqr, JukeboxLightSprite)
    JukeboxLight:setName("JukeLight")
    JukeboxLight:transmitModData()
    sqr:AddTileObject(JukeboxLight)
end
if not currentLamp then
    Jukebox:getModData().MainLight = IsoLightSource.new(Jukebox:getX(), Jukebox:getY(), Jukebox:getZ(), 75, 75, 0, 2)
    JukeboxCell:addLamppost(Jukebox:getModData().MainLight)
end
Jukebox:transmitModData()
''' + text[end:]
        kind = 'jukebox-current-object-native-light-and-overlay-custody'
    elif path == 'client/ISUI/LSMirrorMenu.lua':
        start = text.index('local function MMgetMakeupBottomOptions(')
        end = text.index('\nlocal function MMgetChangeHairBottomOptions(', start)
        section = text[start:end]
        if section.count('previousMakeUp') != 3 or section.count('local makeupItem, idxStart, idxEnd, previousMakeup') != 1:
            raise ValueError('mirror preview transaction seam changed')
        section = section.replace('previousMakeUp', 'previousMakeup')
        section = section.replace('local makeupItem, idxStart, idxEnd, previousMakeup', 'local makeupItem, idxStart, idxEnd, previousMakeup, resetPlayerModel')
        text = text[:start] + section + text[end:]
        kind = 'mirror-preview-transaction-local-worn-snapshot'
    else:
        for name in ['overlayDirtSpriteSub2', 'overlayDirtSpriteSub3']:
            old = '\t' + name + ' = false'
            if text.count(old) != 1:
                raise ValueError('tub constructor ownership seam changed: ' + name)
            text = text.replace(old, '\to.' + name + ' = false', 1)
        kind = 'tub-action-owned-constructor-dirt-fields'
    newline = '\r\n' if b'\r\n' in raw else '\n'
    return text.replace('\n', newline).encode('utf-8'), [{'kind': kind, 'originalVaultUnchanged': True, 'sourceSharedPublishersUnchanged': True}]

def adapt_lifestyle_temporaries(raw: bytes, selected_path: str) -> tuple[bytes, list[dict]]:
    path = selected_path[len("media/lua/"):] if selected_path.startswith("media/lua/") else selected_path
    if path not in LIFESTYLE_TEMPORARY_PREIMAGES:
        return raw, []
    if hashlib.sha256(raw).hexdigest()!=LIFESTYLE_TEMPORARY_PREIMAGES[path]:raise ValueError('source preimage changed: '+path)
    changes=[]
    if path.startswith('client/Instruments/'):
        def localize(m):
            changes.append(m.group(2).decode());return m.group(1)+b'local '+m.group(2)+b' ='
        pattern=rb'(?m)^([ \t]*)(randomNumber|randomTrack|Length)[ \t]*=(?!=)'
        raw=re.sub(pattern,localize,raw)
        helper=rb'(local function LSInstrument(?:PracticeOption|RandomOption|DuetOption|PlayOptions)\([^\r\n]*\)\r\n)'
        raw,count=re.subn(helper,lambda m:m.group(1)+b'\tlocal contextMenu\r\n',raw)
        if count!=4:raise ValueError('instrument helper source scope changed')
        changes.extend(['contextMenu']*count)
        if path.endswith('VanillaInstrumentsContextMenu.lua'):
            old=b'\tType = name';assert raw.count(old)==1;raw=raw.replace(old,b'\tlocal Type = name',1);changes.append('Type')
    elif path=='client/DJBoothContextMenu.lua':
        old=b'DJBoothMenu.doBuildMenu = function(player, context, worldobjects)\r\n';assert raw.count(old)==1
        raw=raw.replace(old,old+b'\tlocal contextMenu1, contextMenu2, contextMenu3, contextMenu4\r\n\tlocal description, descriptionM, descriptionF\r\n',1);changes.extend(sorted({'contextMenu1','contextMenu2','contextMenu3','contextMenu4','description','descriptionM','descriptionF'}))
    elif path=='shared/TimedActions/PlayerIsDancingToMusic.lua':
        for old,new,name in [(b'elseif AnimTime ~= 0 then',b'elseif self.AnimTime ~= 0 then','AnimTime'),(b'isItemInBothHands(handItemP)',b'isItemInBothHands(self.handItemP)','handItemP')]:
            assert raw.count(old)==1;raw=raw.replace(old,new,1);changes.append(name)
    elif path=='server/LSservercommands.lua':
        old=b'\t\t\tobjSpriteName = objSprite.getName and objSprite:getName()';assert raw.count(old)==1;raw=raw.replace(old,b'\t\t\tlocal objSpriteName = objSprite.getName and objSprite:getName()',1);changes.append('objSpriteName')
        old=b'LS_Commands["JukeTurnedOn"] = function(_, arg)\r\n';assert raw.count(old)==1;raw=raw.replace(old,old+b'\tlocal Jukebox, spriteName\r\n',1);changes.extend(['Jukebox','spriteName'])
    else:raise ValueError('unowned path')
    return raw, [{'kind': 'source-per-call-or-action-owned-bindings', 'bindings': sorted(set(changes)), 'sites': len(changes), 'privateOriginalUnchanged': True, 'unrelatedSourceGlobalsPreserved': True}]


def adapt_arcade_punching_text(raw: bytes, selected_path: str) -> tuple[bytes, list[dict]]:
    """Use the installed native text function on the source refusal branch."""
    if selected_path != 'media/lua/client/TimedActions/ProjectArcade_PunchingTimedAction.lua':
        return raw, []
    old = b'Say(GetText("ContextMenu_ProjectArcade_NotEnoughCoins"))'
    if raw.count(old) != 1:
        raise ValueError('Arcade punching text source anchor changed')
    return raw.replace(old, b'Say(getText("ContextMenu_ProjectArcade_NotEnoughCoins"))', 1), [
        {'kind': 'native-punching-refusal-text-function', 'nativeFunction': 'getText',
         'privateOriginalUnchanged': True, 'paymentAndActionLifecycleUnchanged': True}]


LIFESTYLE_LOCALE_COMPATIBILITY = {
    "media/lua/shared/Translate/EN/ContextMenu.json": {
        "ContextMenu_Improvements_FakeRival": "Add Practice Opponent",
        "ContextMenu_LSMP_InUse": "In Use",
        "ContextMenu_LSMP_InvitePlay": "Play Table Tennis",
        "ContextMenu_LSDebug_Ice": "Ice Sculpture",
        "ContextMenu_LSDebug_IceDisplay": "Melt Start Time",
        "ContextMenu_LSDebug_IceMelt": "Advance Melting",
    },
    "media/lua/shared/Translate/EN/Tooltip.json": {
        "Tooltip_CantPerform": "Cannot perform this activity now.",
        "Tooltip_Improvements_HasImp": "This improvement is already installed.",
        "Tooltip_LSMP_InUse": "This table is already in use.",
        "Tooltip_LSMP_NoneNearby": "No other player is nearby to invite.",
    },
    "media/lua/shared/Translate/EN/IG_UI.json": {
        "IGUI_LSSkill_Edit": "Edit Skill Level",
    },
}


LIFESTYLE_CALLBACK_BINDINGS = {
    'media/lua/client/ISAmbt/LSBladeMaster.lua': ('LSBMTick',),
    'media/lua/client/ISAmbt/LSCommando.lua': ('LSCDOnZDead', 'LSCDOnPlayerUpdate'),
    'media/lua/client/ISAmbt/LSElDorado.lua': ('LSEDOnZDead',),
    'media/lua/client/ISAmbt/LSExplorer.lua': ('LSEXOnZDead',),
    'media/lua/client/ISAmbt/LSGoodEating.lua': ('LSGEOnZDead',),
    'media/lua/client/ISAmbt/LSKnockdown.lua': ('LSKDOnZDead',),
    'media/lua/client/ISAmbt/LSLordDeath.lua': ('LSAMBTLDTick', 'LSAMBTLDOnZDead'),
    'media/lua/client/ISAmbt/LSTheProfessional.lua': ('LSTPOnZDead', 'LSTPOnPlayerUpdate'),
}


LIFESTYLE_SOUND_INTERVAL_PATHS = {
    'media/lua/shared/TimedActions/LSCanvasAppraiseAction.lua',
    'media/lua/shared/TimedActions/LSCheckYourself.lua',
    'media/lua/shared/TimedActions/LSCheckYourselfAP.lua',
}


def adapt_lifestyle_sound_interval(raw: bytes, selected_path: str) -> tuple[bytes, list[dict]]:
    """Keep the source repeat-sound schedule on its owning action instance."""
    if selected_path not in LIFESTYLE_SOUND_INTERVAL_PATHS:
        return raw, []
    old = b'\n\t\tsoundTimeInterval = self.soundTime+self.doAnim'
    if raw.count(old) != 1:
        raise ValueError('Lifestyle repeat-sound interval anchor changed: ' + selected_path)
    return raw.replace(old, b'\n\t\tself.soundTimeInterval = self.soundTime+self.doAnim', 1), [
        {'kind': 'action-owned-repeat-sound-interval', 'field': 'self.soundTimeInterval',
         'privateOriginalUnchanged': True, 'sourceRoutineCatalogueUnchanged': True}]


def adapt_lifestyle_callback_bindings(raw: bytes, selected_path: str) -> tuple[bytes, list[dict]]:
    """Bind original removal closures to the exact local source callback owners."""
    names = LIFESTYLE_CALLBACK_BINDINGS.get(selected_path)
    if not names:
        return raw, []
    prefix = b'if not SAO.SourceIntegration.active("LifestyleHobbies") then return end\n'
    if raw.count(prefix) != 1:
        raise ValueError('Lifestyle callback integration prefix changed: ' + selected_path)
    content = raw
    for name in names:
        anchor = ('local function ' + name + '(').encode()
        if content.count(anchor) != 1:
            raise ValueError('Lifestyle callback definition changed: ' + selected_path + ':' + name)
        content = content.replace(anchor, (name + ' = function(').encode(), 1)
    declaration = ('local ' + ', '.join(names) + '\n').encode()
    content = content.replace(prefix, prefix + declaration, 1)
    return content, [{'kind': 'local-event-callback-forward-binding', 'callbacks': list(names),
                      'privateOriginalUnchanged': True, 'callbackBodiesUnchanged': True}]


def adapt_lifestyle_locale_values(values: dict, selected_path: str) -> tuple[dict, list[dict]]:
    additions = LIFESTYLE_LOCALE_COMPATIBILITY.get(selected_path)
    if not additions:
        return values, []
    result = dict(values)
    for key, value in additions.items():
        if key in result and result[key] != value:
            raise ValueError("Lifestyle locale compatibility conflicts with source: " + key)
        result[key] = value
    return result, [{"kind": "source-context-english-locale-compatibility", "keys": sorted(additions), "privateOriginalUnchanged": True}]


def adapt_lifestyle_native_locale(raw: bytes, selected_path: str) -> tuple[bytes, list[dict]]:
    if selected_path != "media/lua/shared/RadioCom/zISRadioInteractions_lsHook.lua":
        return raw, []
    old = b'getText("IGUI_perks_Metalworking"), Perks.MetalWelding'
    if raw.count(old) != 1:
        raise ValueError("Lifestyle native Welding locale source anchor changed")
    return raw.replace(old, b'getText("IGUI_perks_MetalWelding"), Perks.MetalWelding', 1), [{"kind": "native-build42-welding-skill-label", "oldKey": "IGUI_perks_Metalworking", "nativeKey": "IGUI_perks_MetalWelding", "perk": "MetalWelding", "privateOriginalUnchanged": True}]


NAMESPACE_LIFETIME_ADAPTATIONS = {('LifestyleHobbies', 'media/lua/client/Instruments/MusicSheetBookContextMenu.lua'): ('91771bc6e85b292fad360942c8e3cbc6abea39b1ce5f66068525c15de1d0d0db', '556f02f5e07f5a135e3ca374beef4509d980862841c3debfaa81b7201d7108ef', [(8192, 8192, b'local '), (10098, 10098, b'local '), (10656, 10656, b'local '), (10962, 10962, b'local '), (12177, 12177, b'local '), (12479, 12479, b'local '), (13108, 13108, b'local '), (13693, 13693, b'local ')], [{'kind': 'call-owned-source-temporary', 'symbol': 'contextMenu', 'lifetime': 'function', 'privateOriginalUnchanged': True}, {'kind': 'call-owned-source-temporary', 'symbol': 'description', 'lifetime': 'branch', 'privateOriginalUnchanged': True}, {'kind': 'call-owned-source-temporary', 'symbol': 'descriptionR', 'lifetime': 'branch', 'privateOriginalUnchanged': True}, {'kind': 'call-owned-source-temporary', 'symbol': 'descriptionBO', 'lifetime': 'branch', 'privateOriginalUnchanged': True}]), ('LifestyleHobbies', 'media/lua/client/Helper/ContextHelper.lua'): ('e87a54147ffed329a9d79e01eea65835bb9a780a6f1e1ec1a78ea1b997c6b000', 'ac2d83c6c74a2d3016aaea6cb346514d596dc0b29fbc0ebc6c360809faa95bdd', [(3173, 3173, b'local ')], [{'kind': 'call-owned-source-temporary', 'symbol': 'description', 'lifetime': 'branch', 'privateOriginalUnchanged': True}]), ('LifestyleHobbies', 'media/lua/client/Hygiene/BathContextMenu.lua'): ('34bd0106e07bcff65a0293c0e09f3310eb9134abb74e54ffaebca388c9a20cd4', '99a7ff8fdb7e9aa5f678df03ebffe54271879529914cd31c020744d4f3514332', [(12124, 12124, b'local '), (13459, 13459, b'local ')], [{'kind': 'call-owned-source-temporary', 'symbol': 'description', 'lifetime': 'branch', 'privateOriginalUnchanged': True}, {'kind': 'call-owned-source-temporary', 'symbol': 'descriptionC', 'lifetime': 'branch', 'privateOriginalUnchanged': True}]), ('LifestyleHobbies', 'media/lua/client/Hygiene/CabinetContextMenu.lua'): ('ed716c09345f55619d62e802a1e90a7d55cebe1708fbf1ee2e82dda8375aef2d', '850a50efa73dbecae0972325a0f7370ab9537c7e2e4ea4f6b2b48635a42f08fc', [(11614, 11614, b'local '), (11984, 11984, b'local '), (12324, 12324, b'local ')], [{'kind': 'call-owned-source-temporary', 'symbol': 'descriptionBT', 'lifetime': 'branch', 'privateOriginalUnchanged': True}]), ('LifestyleHobbies', 'media/lua/client/Hygiene/MirrorContextMenu.lua'): ('d504c636d446040b32d528273dcefeb0263697d4dea42116d87f27f9f427a334', '0a98b2b6237df5d1deaaa4f2451e6a9592e79054726a9a79bb03be32ce6b2a9b', [(7821, 7821, b'local '), (8179, 8179, b'local '), (8498, 8498, b'local '), (15476, 15476, b'local ')], [{'kind': 'call-owned-source-temporary', 'symbol': 'descriptionBT', 'lifetime': 'branch', 'privateOriginalUnchanged': True}, {'kind': 'call-owned-source-temporary', 'symbol': 'description', 'lifetime': 'branch', 'privateOriginalUnchanged': True}]), ('LifestyleHobbies', 'media/lua/client/Hygiene/PerfumeContextMenu.lua'): ('5b52db563e1300cc871156ad85351a773ec07672745e9e6ce329c10c0cca0811', '71170ad26f9fcc8525520ea0081f8a3b644ddbf6ca2abf33c2c7d76da321c0e7', [(2412, 2412, b'local ')], [{'kind': 'call-owned-source-temporary', 'symbol': 'description', 'lifetime': 'function', 'privateOriginalUnchanged': True}]), ('LifestyleHobbies', 'media/lua/client/Hygiene/ShowerContextMenu.lua'): ('c519dd8610b4de6586b6529dcdd682e718255745d80b9af905fe70f00b0a7ebd', 'e9df65e1a50d42116c1a048618a16326aa0f02c07cf6825a616edae852507c52', [(2999, 2999, b'local '), (7678, 7678, b'local ')], [{'kind': 'call-owned-source-temporary', 'symbol': 'description', 'lifetime': 'branch', 'privateOriginalUnchanged': True}, {'kind': 'call-owned-source-temporary', 'symbol': 'descriptionC', 'lifetime': 'branch', 'privateOriginalUnchanged': True}]), ('LifestyleHobbies', 'media/lua/client/ISAmbt/LSPlushies.lua'): ('9a58c574f9282acee07901340df3118e9042d692c5f477a48bcee4203d148326', '644deda8182a59d6ac668d11efa58fb1f2de2c8265970049ed6f4e32b02b42bd', [(2784, 2784, b'local ')], [{'kind': 'call-owned-source-temporary', 'symbol': 'moodList', 'lifetime': 'branch', 'privateOriginalUnchanged': True}]), ('LifestyleHobbies', 'media/lua/client/Instruments/InstrumentPianoContextMenu.lua'): ('a433382fc0c37f2379847634a6c56f484330c09ca02fc34910322c15b2fa3979', 'd3808f87e671cded8f4c2d8b82ae8628d48a607e2a09f2771f6d5048173d4b1f', [(6032, 6032, b'local ')], [{'kind': 'call-owned-source-temporary', 'symbol': 't', 'lifetime': 'branch', 'privateOriginalUnchanged': True}]), ('LifestyleHobbies', 'media/lua/client/LSEffects/LSPerHour.lua'): ('a66ba3458ed03570a6aca8570c944e8594a39e58dc439a4bce6547cb91c49fd4', 'ef0df1c31975234a20e05ea574c095ba41e79f9846ed67a9e7719fbef5c97a56', [(3864, 3864, b'local '), (4062, 4062, b'local ')], [{'kind': 'call-owned-source-temporary', 'symbol': 't', 'lifetime': 'branch', 'privateOriginalUnchanged': True}, {'kind': 'call-owned-source-temporary', 'symbol': 'severity', 'lifetime': 'branch', 'privateOriginalUnchanged': True}]), ('LifestyleHobbies', 'media/lua/client/JukeboxContextMenuAux.lua'): ('1f0243c4061ca14f6a93b47fd6254a4b27d2f2158a5601baf250d4af571b97c9', '9407a73ee5d95f839d8ba11ea912d147412de54cad5924d6684666d67a0eaf8d', [(4469, 4469, b'local ')], [{'kind': 'call-owned-source-temporary', 'symbol': 'option', 'lifetime': 'branch', 'privateOriginalUnchanged': True}]), ('LifestyleHobbies', 'media/lua/client/MPSocial/InteractionManager.lua'): ('2eda09f07bc054aa490d50b1b1a1e8e820805b78b70a389bb673f29eb3c090b1', 'b6a7195b574479ea5baec3ca92a0c45ec179206856182f712d357ba3e591e0f4', [(5244, 5244, b'local '), (5625, 5625, b'local '), (6170, 6170, b'local '), (6460, 6460, b'local '), (8360, 8360, b'local '), (8648, 8648, b'local ')], [{'kind': 'call-owned-source-temporary', 'symbol': 'doTimedAction', 'lifetime': 'branch', 'privateOriginalUnchanged': True}, {'kind': 'call-owned-source-temporary', 'symbol': 'otherPlayer', 'lifetime': 'branch', 'privateOriginalUnchanged': True}]), ('LifestyleHobbies', 'media/lua/shared/TimedActions/LSYogaAction.lua'): ('72ece53c2c0b0743add973f81580521347a558a5ab78bffcf22d8806e16a5a82', 'c38b92d842b6e9426fd69272a47cf1cbd57058c5a73633e6fce1f5b80a93cc65', [(2389, 2389, b'local ')], [{'kind': 'call-owned-source-temporary', 'symbol': 'objAdjSqr', 'lifetime': 'branch', 'privateOriginalUnchanged': True}]), ('LifestyleHobbies', 'media/lua/client/Painting/Sculpting/SculptingWorkContextMenu.lua'): ('14436b8df3ec7784d219093737646efc3dcf2de979a1bb2365317123f08d8db8', '89491ff8846d4e9dc68c1b334b93b79ac412a6ef71f04cd7029d63209b4b1ed6', [(17189, 17189, b'local missingItems\n\t\t')], [{'kind': 'call-owned-source-temporary', 'symbol': 'missingItems', 'lifetime': 'mixed-return', 'privateOriginalUnchanged': True}]), ('NewMusic', 'media/lua/client/ui/shared/slots/NMSlotGhostOverlay.lua'): ('cebb76342ade7931bb88202d9921f426ba33e4caef9e0c8eb376861c85199822', 'cb0523dc573b06e98c3c83b2232d58f568e4d04f3a0f450cc9fa014496c39582', [(1738, 1738, b'local _\n        ')], [{'kind': 'call-owned-source-temporary', 'symbol': '_', 'lifetime': 'discard', 'privateOriginalUnchanged': True}]), ('LifestyleHobbies', 'media/lua/client/ISAmbt/LSExplorer.lua'): ('31c54080b057255026680d77a28849753d4a0b1dee9da55f0f06003bc6bfbff7', '5cdc1e05ebd06de8e3eacb7c6e909d6aaf4d412d98a8b13ae14d2895d5c9ccc7', [(2357, 3707, b''), (3815, 3844, b'')], [{'kind': 'native-worldmap-instance-owner-preserved', 'privateOriginalUnchanged': True, 'pendingState': 'existing LSAMBTEXEvent unchanged while native instance absent', 'nativeFactoryUnchanged': True}]), ('LifestyleHobbies', 'media/lua/client/ISUI/LSMirrorMenu.lua'): ('d35ac92e989e0afeeac0e0d8e8c79ba348ebe49b8a8adf89c967b99990bc69ec', 'f83eccc5a4c1b80607d5eb24955402c50acfdc67e86370e117109fcf6930d081', [(2016, 2035, b'\t\tlocal item = it:get(j);')], [{'kind': 'call-owned-source-temporary', 'symbol': 'item', 'lifetime': 'function', 'privateOriginalUnchanged': True}]), ('LifestyleHobbies', 'media/lua/shared/TimedActions/LSUseTub.lua'): ('19643812e1c55a5b168d9e8dfb6a017ca87a441a4aa47aebad73c583e91f666e', '3ac8159ecac6228eab8e19c5f1a47157178d19efec2af51ffec4ae70f02d4514', [(5816, 5832, b'\tlocal TubAnimList = {')], [{'kind': 'call-owned-source-temporary', 'symbol': 'TubAnimList', 'lifetime': 'function', 'privateOriginalUnchanged': True}]), ('LifestyleHobbies', 'media/lua/client/DiscoFloorInteractionRangeMain.lua'): ('66f260a7d35e64fd3f535cf0f9f4e139f453ad7b5d3a75b064e3136ceb53d5b6', '3be2e79c6c613f37563659aae0b4a0000aba0951f7f09af9b4a9caff21d99fa1', [(9686, 9808, b'\t\t\t\t\tif (not mainDFobj) or (not sqrHasEnergy(mainDFobj)) then v:getModData().Connected = false; v:getModData().DFOnOff = "off";\r\n')], [{'kind': 'exact-source-branch-owner', 'symbol': 'DF', 'owner': 'mainDFobj', 'reachability': 'inner IsMainDF false branch is dormant under stable outer IsMainDF true; native proof controls a scene change during player range host read'}]), ('LifestyleHobbies', 'media/lua/client/MPSocial/ShareKnowledgeContextMenu.lua'): ('5848d53765769c86895c69093931ad20b8ae09b0d962367b41b6e66e49cc915f', 'b40c038dd3684e1d10f388c1cda8f1b499d9b381bd544add3c5a3be3f1014344', [(5923, 5973, b'\tlocal LSSKAction = require("TimedActions/LSSKAction")\r\n'), (6294, 6365, b'\t\tlocal LSWaitForInteraction = require("TimedActions/LSWaitForInteraction")\r\n')], [{'kind': 'require-result-call-owned-reader', 'symbol': 'LSSKAction', 'provider': 'shared/TimedActions/LSSKAction.lua', 'lifetime': 'onSKAction call local'}, {'kind': 'require-result-call-owned-reader', 'symbol': 'LSWaitForInteraction', 'provider': 'shared/TimedActions/LSWaitForInteraction.lua', 'lifetime': 'onSKAction call local'}]), ('ComputerModkum', 'media/lua/client/ComputerMod_ContextMenu.lua'): ('1de784964aba672223bb5fa009ecba46f8cc64fd06e0cb95a07965dd4c9f6766', 'daaf86cb7203464bb2d530fad6b83b07247bead3dc3e4a3b18a3e12197bbceb4', [(4871, 5045, b'    if instanceItem then\n        local okCreate, created = pcall(function() return instanceItem(fullType) end)\n')], [{'kind': 'installed-exposed-item-creation-route', 'oldReader': 'InventoryItemFactory.CreateItem', 'provider': 'zombie.Lua.LuaManager.GlobalObject.instanceItem(String)', 'arguments': 'one current validated fullType String (or item.fullType / entry.id)', 'factoryReadsRemoved': 1, 'fallbackPolicy': 'existing nil/error and AddItem fallback behavior retained; redundant obsolete class fallback removed where instanceItem already used'}]), ('ComputerModkum', 'media/lua/client/ComputerMod_UI.lua'): ('ac66c583ab4398576deb3f30437fba34a5283e88c062959f77cfbf2e9bcac806', '35ea7feed25a2113fa9aca10b91e22d9e3f9685b788dab9326f643153e85e624', [(25377, 25551, b'    if instanceItem then\n        local okCreate, created = pcall(function() return instanceItem(fullType) end)\n')], [{'kind': 'installed-exposed-item-creation-route', 'oldReader': 'InventoryItemFactory.CreateItem', 'provider': 'zombie.Lua.LuaManager.GlobalObject.instanceItem(String)', 'arguments': 'one current validated fullType String (or item.fullType / entry.id)', 'factoryReadsRemoved': 1, 'fallbackPolicy': 'existing nil/error and AddItem fallback behavior retained; redundant obsolete class fallback removed where instanceItem already used'}]), ('ComputerModkum', 'media/lua/client/ComputerMod_RelayRepairUI.lua'): ('d53e2097827545ffa4cdc4caba409b99d94bd29edfd7b655097c2e2ae7aa8046', '06366c4a7272f1183a65d503759a1596fc00659457df23afb17996b7b3941c64', [(1582, 1750, b'    if instanceItem then\n        local ok, created = pcall(function() return instanceItem(fullType) end)\n')], [{'kind': 'installed-exposed-item-creation-route', 'oldReader': 'InventoryItemFactory.CreateItem', 'provider': 'zombie.Lua.LuaManager.GlobalObject.instanceItem(String)', 'arguments': 'one current validated fullType String (or item.fullType / entry.id)', 'factoryReadsRemoved': 1, 'fallbackPolicy': 'existing nil/error and AddItem fallback behavior retained; redundant obsolete class fallback removed where instanceItem already used'}]), ('ComputerModkum', 'media/lua/client/ComputerMod_UI_Render.lua'): ('8a16c5b4c4f26e8eccc65933c1783334f6bc2e7c939ee043f7063824084e27be', '90c3a312024a80789be9504a3bb222f5ff146ffcf5787fd613c4f578f7a8ba8b', [(53017, 53214, b'    if item.fullType and instanceItem then\n        local ok, inventoryItem = pcall(function() return instanceItem(item.fullType) end)\n')], [{'kind': 'installed-exposed-item-creation-route', 'oldReader': 'InventoryItemFactory.CreateItem', 'provider': 'zombie.Lua.LuaManager.GlobalObject.instanceItem(String)', 'arguments': 'one current validated fullType String (or item.fullType / entry.id)', 'factoryReadsRemoved': 1, 'fallbackPolicy': 'existing nil/error and AddItem fallback behavior retained; redundant obsolete class fallback removed where instanceItem already used'}]), ('ComputerModkum', 'media/lua/client/ComputerMod_UI_System.lua'): ('4b3e840b7ba19226ef93682e341df75c13b232cbc0e2f099fd98bbc2a03be54b', '718821cc80fd7a15c968027a94af22642184aafda27d0e961c18b04ae7efc37f', [(118185, 118424, b'')], [{'kind': 'installed-exposed-item-creation-route', 'oldReader': 'InventoryItemFactory.CreateItem', 'provider': 'zombie.Lua.LuaManager.GlobalObject.instanceItem(String)', 'arguments': 'one current validated fullType String (or item.fullType / entry.id)', 'factoryReadsRemoved': 1, 'fallbackPolicy': 'existing nil/error and AddItem fallback behavior retained; redundant obsolete class fallback removed where instanceItem already used'}]), ('ComputerModkum', 'media/lua/client/ComputerMod_UI_State.lua'): ('648208f5accb617f78fdf711b181aa2344ecb3eb06db7f568cdad37dc56fa7ca', '8aba75927d88c8dc6c5efd9d80a680894b4596b38f19010548dfdc679073071f', [(61977, 62142, b'    if instanceItem then\n        local ok, item = pcall(function() return instanceItem(fullType) end)\n'), (81568, 81705, b'        if instanceItem then\n            local ok, item = pcall(function() return instanceItem(entry.id) end)\n')], [{'kind': 'installed-exposed-item-creation-route', 'oldReader': 'InventoryItemFactory.CreateItem', 'provider': 'zombie.Lua.LuaManager.GlobalObject.instanceItem(String)', 'arguments': 'one current validated fullType String (or item.fullType / entry.id)', 'factoryReadsRemoved': 2, 'fallbackPolicy': 'existing nil/error and AddItem fallback behavior retained; redundant obsolete class fallback removed where instanceItem already used'}]), ('ComputerModkum', 'media/lua/server/ComputerMod_CD_Server.lua'): ('52caadc99c3bab5c9920fd96e16fe7e145df67b6f30baf0dcb0747a883a9bf14', '51aefd90bac2b662004690ddb6678788c49b73f4a4d8a2a6a74bfcedec6dacb4', [(9818, 9992, b'    if instanceItem then\n        local okCreate, created = pcall(function() return instanceItem(fullType) end)\n')], [{'kind': 'installed-exposed-item-creation-route', 'oldReader': 'InventoryItemFactory.CreateItem', 'provider': 'zombie.Lua.LuaManager.GlobalObject.instanceItem(String)', 'arguments': 'one current validated fullType String (or item.fullType / entry.id)', 'factoryReadsRemoved': 1, 'fallbackPolicy': 'existing nil/error and AddItem fallback behavior retained; redundant obsolete class fallback removed where instanceItem already used'}]), ('ComputerModkum', 'media/lua/server/ComputerMod_ComputerData_Server.lua'): ('c0b48970e7abb03f895dbe6aad8e7b887e9460121f969347c49cf2446831c930', 'c11b7b2df980948fe70abc5e6b003a9b0f80f2e61b747d2c00b8a92c4091c998', [(11546, 11686, b'    if not instanceItem then return end\n    local ok, item = pcall(function() return instanceItem(fullType) end)\n')], [{'kind': 'installed-exposed-item-creation-route', 'oldReader': 'InventoryItemFactory.CreateItem', 'provider': 'zombie.Lua.LuaManager.GlobalObject.instanceItem(String)', 'arguments': 'one current validated fullType String (or item.fullType / entry.id)', 'factoryReadsRemoved': 1, 'fallbackPolicy': 'existing nil/error and AddItem fallback behavior retained; redundant obsolete class fallback removed where instanceItem already used'}]), ('ComputerModkum', 'media/lua/server/ComputerMod_Market_Server.lua'): ('a316be8b713306b3a99816df673a972d112bff08e81b188c64de3bda4dd9b0c8', 'fe3ab856dbfb8fe9fc16e06d67fdde0ed7f07769df3b8105bec340d5a804a5f8', [(3567, 3806, b'')], [{'kind': 'installed-exposed-item-creation-route', 'oldReader': 'InventoryItemFactory.CreateItem', 'provider': 'zombie.Lua.LuaManager.GlobalObject.instanceItem(String)', 'arguments': 'one current validated fullType String (or item.fullType / entry.id)', 'factoryReadsRemoved': 1, 'fallbackPolicy': 'existing nil/error and AddItem fallback behavior retained; redundant obsolete class fallback removed where instanceItem already used'}]), ('NewMusic', 'media/lua/client/runtime/NMClientZombieVisualProbe.lua'): ('255f2443e86dda599298db6fe2b347c1c3ed12b733fd00995372a42bc7ee686b', '957aad6cf2eefc322680a0a7bb608a2cb83cf79b6fa698ae00e84274ac159002', [(11832, 11978, b'    if instanceItem then\n        local ok, created = pcall(instanceItem, fullType)\n')], [{'kind': 'installed-exposed-item-creation-route', 'oldReader': 'InventoryItemFactory.CreateItem', 'provider': 'zombie.Lua.LuaManager.GlobalObject.instanceItem(String)', 'arguments': 'one current validated fullType String (or item.fullType / entry.id)', 'factoryReadsRemoved': 1, 'fallbackPolicy': 'existing nil/error and AddItem fallback behavior retained; redundant obsolete class fallback removed where instanceItem already used'}]), ('LifestyleHobbies', 'media/lua/client/LSMoodleManager.lua'): ('26bd5979a248ac49b46066558e6368052950c3371c6ccce38132bf68d1bc7659', 'dc480301ffa4b22da12d5d58178d3fc0663d36743b6507296e031ad50074a36d', [(17954, 18003, b'local playerMoodleData = MF.MoodleData[tostring(player)]\n\t\tlocal allMoodles = playerMoodleData and playerMoodleData.Moodles or {}')], [{'kind': 'optional-provider-exact-existing-player-read', 'provider': 'MoodleFramework 42.20 MF_ISMoodle.lua', 'oldReceiver': 'MF.ISMoodle class has no char/name; getMoodleData is instance-owned', 'newReader': 'existing MF.MoodleData[tostring(player)].Moodles, or empty call-local table', 'persistence': 'provider cache read only, no player/provider row creation'}])}

def adapt_source_namespace_lifetimes(raw, source_id, selected_path):
    spec = NAMESPACE_LIFETIME_ADAPTATIONS.get((source_id, selected_path))
    if not spec:
        return raw, []
    preimage, postimage, edits, metadata = spec
    if sha(raw) != preimage:
        raise ValueError('Source namespace lifetime preimage changed: ' + source_id + ':' + selected_path)
    content = raw
    for start, end, replacement in reversed(edits):
        content = content[:start] + replacement + content[end:]
    if sha(content) != postimage:
        raise ValueError('Source namespace lifetime postimage changed: ' + source_id + ':' + selected_path)
    return content, [dict(row) for row in metadata]


RESIDUAL_LIFESTYLE_ADAPTATIONS = {('LifestyleHobbies', 'media/lua/client/ISUI/LSDebugConfirm.lua'): ('5d24d71d513a366e044131efa9118fc1af7e3311eaa576822767ebc1fe4cd5ba', '8e63cb89507b3b781730131dd45b953c792a892ef8cb59f657b2601c630c05fa', [(4688, 4720, b'')], [{'kind': 'exact-residual-source-owner-repair', 'privateOriginalUnchanged': True, 'changes': [{'old': '\to.ogAmbt = AMBT\r\n', 'new': '', 'count': 1, 'contract': 'unused constructor vestige'}, {'old': '\to.key = Key\r\n', 'new': '', 'count': 1, 'contract': 'unused copied field; no declared Key argument'}]}]), ('LifestyleHobbies', 'media/lua/client/MPSocial/InteractionManager.lua'): ('b6a7195b574479ea5baec3ca92a0c45ec179206856182f712d357ba3e591e0f4', 'f87b53bbd3edcb397488684c96f714dec0d60e3226b292aded6fc8d8293fbf88', [(8035, 8100, b'\t\tlocal objSpriteName = obj and LSUtil.getObjSpriteName(obj)\r\n')], [{'kind': 'exact-residual-source-owner-repair', 'privateOriginalUnchanged': True, 'changes': [{'old': 'LSUtil.getObjSpriteName(adjObj)', 'new': 'LSUtil.getObjSpriteName(obj)', 'count': 1, 'contract': 'exact iterated object'}]}]), ('LifestyleHobbies', 'media/lua/server/LSservercommands.lua'): ('d91b88bc0bb79321850f1b3fa655cc46edc629d2e5c4ebeaa903ac959f218c5a', 'eb9de5d99f72cb9c585a25ac469cada05b6a2e185fb6eabd5decc464ce67075f', [(3238, 3290, b'\t\t\tlocal bagContainer = bag and bag.getItemContainer and bag:getItemContainer()\r\n'), (9538, 9566, b'\tif upMood == "WETNESS" then\r\n'), (9654, 9818, b'\t\tif method == "set" then\r\n\t\t\tlocal parts = bodyDamage:getBodyParts()\r\n\t\t\tfor n=0,parts:size()-1 do parts:get(n):setWetness(value); end\r\n\t\telse\r\n\t\t\tif method == "add" then wetMethod = "increaseBodyWetness"; end\r\n\t\t\tbodyDamage[wetMethod](bodyDamage, value)\r\n\t\tend\r\n'), (10952, 11028, b'\tplayer:modifyTraitXPBoost(CharacterTrait[trait], method == "remove");\r\n'), (23997, 24019, b'\tif movabledata then\r\n\t\titemData.movableData = itemData.movableData or {}\r\n')], [{'kind': 'exact-residual-source-owner-repair', 'privateOriginalUnchanged': True, 'changes': [{'old': 'local bagContainer = bad and bag:getContainer()', 'new': 'local bagContainer = bag and bag.getItemContainer and bag:getItemContainer()', 'count': 1, 'contract': 'native InventoryContainer contents; getContainer is parent ownership'}, {'old': 'if mood == "WETNESS" then', 'new': 'if upMood == "WETNESS" then', 'count': 1, 'contract': 'current command mood argument'}, {'old': 'if method == "add" then wetMethod = "increaseBodyWetness"; elseif method == "set" then wetMethod = "setWetness"; end\r\n\t\tbodyDamage[wetMethod](bodyDamage, value)', 'new': 'if method == "set" then\r\n\t\t\tlocal parts = bodyDamage:getBodyParts()\r\n\t\t\tfor n=0,parts:size()-1 do parts:get(n):setWetness(value); end\r\n\t\telse\r\n\t\t\tif method == "add" then wetMethod = "increaseBodyWetness"; end\r\n\t\t\tbodyDamage[wetMethod](bodyDamage, value)\r\n\t\tend', 'count': 1, 'contract': 'installed BodyDamage has increment/decrement; owned BodyPart.setWetness is actual setter'}, {'old': 'if movableData then\r\n\t\tfor k, v in pairs(movabledata) do', 'new': 'if movabledata then\r\n\t\titemData.movableData = itemData.movableData or {}\r\n\t\tfor k, v in pairs(movabledata) do', 'count': 1, 'contract': 'owned supplied movable state; preserve other fields'}, {'old': 'CharacterTrait[traitName]', 'new': 'CharacterTrait[trait]', 'count': 1, 'contract': 'current changed trait argument'}]}]), ('LifestyleHobbies', 'media/lua/client/Properties/Objects/beauty.lua'): ('a62968a7aacd3425f99bec2150d8ac5a52d1af6766d83774b3b1da15731fd645', 'f26f5e136057854d49b4afb111d6b42fcdb77f67f2f1753cff95540a07d33954', [(41596, 41751, b'')], [{'kind': 'exact-residual-source-owner-repair', 'privateOriginalUnchanged': True, 'changes': [{'old': '\t\tlocal finalBeauty\r\n\t\tif beauty then\r\n\t\t\tif beauty < 0 then finalBeauty = math.floor(beauty*mult); else finalBeauty = math.ceil(beauty*mult); end\r\n\t\tend\r\n', 'new': '', 'count': 1, 'contract': 'unused post-scaling expression; scaling remains once'}]}]), ('LifestyleHobbies', 'media/lua/shared/Hygiene/ToiletFunctions.lua'): ('fe3103a1ac83bf9cd5cb3588e2ff9fdd8c854f234c317bdc9a5ebe14383d6cbd', '6eebc3e196034fa22415525059428789fbe8da5a2fd4e7e47d2fdfe248713bbc', [(9105, 9190, b'')], [{'kind': 'exact-residual-source-owner-repair', 'privateOriginalUnchanged': True, 'changes': [{'old': '\t\tif not containsItem then LSUtil.debugPrint("LSUseToilet - not containsItem"); end\r\n', 'new': '', 'count': 1, 'contract': 'stale diagnostic; real consumption/transfer remains'}]}]), ('LifestyleHobbies', 'media/lua/client/ISUI/LSMirrorMenu.lua'): ('f83eccc5a4c1b80607d5eb24955402c50acfdc67e86370e117109fcf6930d081', '82f40b39b39050ddb04694d4c16cba4838e4ceed9eda61c441bf255793b6d1c5', [(3456, 3456, b'local function MMhasTattooChange(self)\r\n\tlocal categories = {{"Face_Tattoo","resetMakeupTattooFace"},{"UpperBody_Tattoo","resetMakeupTattooUB"},{"LowerBody_Tattoo","resetMakeupTattooLB"},{"Back_Tattoo","resetMakeupTattooBack"},{"LeftArm_Tattoo","resetMakeupTattooLA"},{"RightArm_Tattoo","resetMakeupTattooRA"},{"LeftLeg_Tattoo","resetMakeupTattooLL"},{"RightLeg_Tattoo","resetMakeupTattooRL"}}\r\n\tfor _, category in ipairs(categories) do\r\n\t\tif self[category[2]] ~= 0 then\r\n\t\t\tlocal current = MMgetMakeupBodyLocationItem(self.character, category[1])\r\n\t\t\tif current and current ~= self[category[2]] then return true; end\r\n\t\tend\r\n\tend\r\n\treturn false\r\nend\r\n\r\n'), (3504, 3504, b'\tlocal useTattoo = MMhasTattooChange(self)\r\n'), (5964, 6167, b'\t\tsendClientCommand(self.character, "LS", "SetMirrorMakeup", {{self.hairDyeItem, self.beardDyeItem, useTattoo and self.itemsList.MakeupTattooNeedle, self.acidBrush and self.itemsList.MakeupTattooBrush}, makeupData})\r\n'), (32471, 32570, b'\t\tMMbottomMenuButtonList[1]:setOnClick(onClickMakeupPreview, makeup, makeupCat, 1, false)\r\n'), (35974, 36078, b'\t\tMMbottomMenuButtonList[1]:setOnClick(onClickChangeHairPreview, hairStyle, isBeard, 1, false)\r\n'), (38953, 39052, b'\t\tMMbottomMenuButtonList[1]:setOnClick(onClickDyeHairPreview, dyeItem, isBeard, 1, false)\r\n')], [{'kind': 'exact-residual-source-owner-repair', 'privateOriginalUnchanged': True, 'changes': [{'old': 'function LSMirrorMenu:onConfirmChanges(button)', 'new': 'local function MMhasTattooChange(self)\r\n\tlocal categories = {{"Face_Tattoo","resetMakeupTattooFace"},{"UpperBody_Tattoo","resetMakeupTattooUB"},{"LowerBody_Tattoo","resetMakeupTattooLB"},{"Back_Tattoo","resetMakeupTattooBack"},{"LeftArm_Tattoo","resetMakeupTattooLA"},{"RightArm_Tattoo","resetMakeupTattooRA"},{"LeftLeg_Tattoo","resetMakeupTattooLL"},{"RightLeg_Tattoo","resetMakeupTattooRL"}}\r\n\tfor _, category in ipairs(categories) do\r\n\t\tif self[category[2]] ~= 0 then\r\n\t\t\tlocal current = MMgetMakeupBodyLocationItem(self.character, category[1])\r\n\t\t\tif current and current ~= self[category[2]] then return true; end\r\n\t\tend\r\n\tend\r\n\treturn false\r\nend\r\n\r\nfunction LSMirrorMenu:onConfirmChanges(button)\r\n\tlocal useTattoo = MMhasTattooChange(self)', 'count': 1, 'contract': 'instance pending captured/current tattoo comparison; no constant or global'}, {'old': 'self.beardDyeItem, self.itemsList.MakeupTattooNeedle, self.acidBrush', 'new': 'self.beardDyeItem, useTattoo and self.itemsList.MakeupTattooNeedle, self.acidBrush', 'count': 1, 'contract': 'client command supplies needle only for its captured/current tattoo change; actual server provider consumes supplied truthy items'}, {'old': 'MMbottomMenuButtonList[1]:setOnClick(onClickMakeupPreview, makeup, makeupCat, idxStatic, false)', 'new': 'MMbottomMenuButtonList[1]:setOnClick(onClickMakeupPreview, makeup, makeupCat, 1, false)', 'count': 1, 'contract': 'single result owns slot one'}, {'old': 'MMbottomMenuButtonList[1]:setOnClick(onClickChangeHairPreview, hairStyle, isBeard, idxStatic, false)', 'new': 'MMbottomMenuButtonList[1]:setOnClick(onClickChangeHairPreview, hairStyle, isBeard, 1, false)', 'count': 1, 'contract': 'single result owns slot one'}, {'old': 'MMbottomMenuButtonList[1]:setOnClick(onClickDyeHairPreview, dyeItem, isBeard, idxStatic, false)', 'new': 'MMbottomMenuButtonList[1]:setOnClick(onClickDyeHairPreview, dyeItem, isBeard, 1, false)', 'count': 1, 'contract': 'single result owns slot one'}]}]), ('LifestyleHobbies', 'media/lua/shared/TimedActions/hooks/Read.lua'): ('bc6a3fbaa7d4bb1ee0e418fa467ff7e41c4359cf3a6d432485bf6f798f6f3ccd', '95ddfeb0a624449618ff0388f5cb70ff78d90a0a063e2140c354b894d73ed5c5', [(1569, 1792, b'\t\telseif neuralBonus[state] then\r\n\t\t\tlocal data = headgear:getModData()\r\n\t\t\tlocal invData = data and data[\'invData\']\r\n\t\t\tlocal efficiency = type(invData) == "table" and type(invData.efficiencyMult) == "table" and tonumber(invData.efficiencyMult[2])\r\n\t\t\tif efficiency and efficiency > 0 then\r\n\t\t\t\tlocal readBonus = state == 1 and invData.fastRead and 0.5 or 1\r\n\t\t\t\tlocal mult = math.max(0.1,math.min(1, neuralBonus[state]/efficiency))\r\n\t\t\t\ttime = (time*readBonus)*mult\r\n'), (1800, 1925, b'')], [{'kind': 'exact-residual-source-owner-repair', 'privateOriginalUnchanged': True, 'changes': [{'old': "\t\telseif state ~= 0 then\r\n\t\t\tlocal readBonus = 1\r\n\t\t\tif state == 1 then\r\n\t\t\t\tlocal data = headgear:getModData()\r\n\t\t\t\tlocal invData = data and data['invData']\r\n\t\t\t\tif invData and invData['fastRead'] then readBonus=0.5; end\r\n\t\t\tend\r\n\t\t\tlocal mult = math.max(0.1,math.min(1, neuralBonus[state]/invData['efficiencyMult'][2]))\r\n\t\t\ttime = (time*readBonus)*mult", 'new': '\t\telseif neuralBonus[state] then\r\n\t\t\tlocal data = headgear:getModData()\r\n\t\t\tlocal invData = data and data[\'invData\']\r\n\t\t\tlocal efficiency = type(invData) == "table" and type(invData.efficiencyMult) == "table" and tonumber(invData.efficiencyMult[2])\r\n\t\t\tif efficiency and efficiency > 0 then\r\n\t\t\t\tlocal readBonus = state == 1 and invData.fastRead and 0.5 or 1\r\n\t\t\t\tlocal mult = math.max(0.1,math.min(1, neuralBonus[state]/efficiency))\r\n\t\t\t\ttime = (time*readBonus)*mult\r\n\t\t\tend', 'count': 1, 'contract': 'headgear-owned enclosing data; supported states and positive efficiency; invalid data retains base'}]}]), ('LifestyleHobbies', 'media/lua/client/ISUI/DJSoundboardOverlay.lua'): ('386b25bd559dd93934ec8042250f322d368e8c4ce4c4ae636fec7f6e957afe26', 'cdb5a799ea8db0a321d3ae614855623789079b219c676556e044cc6b6c9be9b7', [(30226, 30244, b'')], [{'kind': 'exact-residual-source-owner-repair', 'privateOriginalUnchanged': True, 'changes': [{'symbol': 'new', 'contract': 'unused copied field; preserve inherited actual constructor'}]}]), ('LifestyleHobbies', 'media/lua/client/ISUI/PlaylistImportConfirm.lua'): ('8ccac4bbb3e200e842dd496e7128d75cb87a766a87c40a05e424b14fc61a7fb6', '66d8dad6c8995eba78984be4d2553d07e31eca756053f3f5873ef6ba920bc164', [(1105, 1151, b'\tlocal specificPlayer = self.character\r\n'), (4076, 4123, b'\t\tlocal specificPlayer = self.character\r\n'), (4807, 4854, b'\t\tlocal specificPlayer = self.character\r\n'), (6964, 7008, b''), (7149, 7167, b'')], [{'kind': 'exact-residual-source-owner-repair', 'privateOriginalUnchanged': True, 'changes': [{'symbol': 'new', 'contract': 'unused copied field; preserve inherited actual constructor'}, {'symbol': 'target', 'contract': 'unused copied field; actual character/index/button owner retained'}, {'symbol': 'onclick', 'contract': 'unused copied field; actual character/index/button owner retained'}, {'old': 'local specificPlayer = getSpecificPlayer(0)', 'new': 'local specificPlayer = self.character', 'count': 3, 'contract': 'existing constructor-captured confirmation/close recipient'}]}]), ('LifestyleHobbies', 'media/lua/client/ISUI/WardrobeConfirm.lua'): ('cb93a167b8673e9789b02e8f2cf43c0838d17a5b6baba926108c6b0715907365', 'be4cf291398f8b48a203388ad331e48451566a7a43826be2302e4aea8a8537ee', [(5934, 5978, b''), (6166, 6184, b'')], [{'kind': 'exact-residual-source-owner-repair', 'privateOriginalUnchanged': True, 'changes': [{'symbol': 'new', 'contract': 'unused copied field; preserve inherited actual constructor'}, {'symbol': 'target', 'contract': 'unused copied field; actual character/index/button owner retained'}, {'symbol': 'onclick', 'contract': 'unused copied field; actual character/index/button owner retained'}]}]), ('LifestyleHobbies', 'media/lua/shared/TimedActions/LSInvHarvesterAction.lua'): ('e6a0ff156a809ae5c66c5255a0da0818221f66b086f229d6cd3e25f094bee539', '7d07a44bb1ba3d646f6e306253f89da9ba740f29ec50f7898bbb12f029005995', [(6279, 6435, b"\tif self.ogFuel < self.data['fuelUses'] and self.item and not self.item:isBroken() and not LSUtil.isCooldown(self.data) then LSSync.transmit(self.item); end\r\n")], [{'kind': 'exact-residual-source-owner-repair', 'privateOriginalUnchanged': True, 'changes': [{'old': 'self.item:isBroken() and not LSUtil.isCooldown(tA.data)', 'new': 'self.item:isBroken() and not LSUtil.isCooldown(self.data)', 'count': 1, 'contract': 'current action owned fuel/cooldown data; retain correctly parameterized helper tA'}]}]), ('LifestyleHobbies', 'media/lua/server/LSservercmdhandler.lua'): ('e919f7a714d7d8c65a1a9ab9ed423e81295173b74a19ac2ce552823bac25c406', 'a5613c4def31339e50958e3327d6df733ef25216628ed85c4253e3ee5f7e64b3', [(975, 1081, b'\t\tlocal NewLitterObj = IsoObject.new(entity, spriteName)\r\n\t\tentity:AddTileObject(NewLitterObj)\r\n')], [{'kind': 'exact-residual-source-owner-repair', 'privateOriginalUnchanged': True, 'changes': [{'old': 'IsoObject.new(targetFloor, spriteName)', 'new': 'IsoObject.new(entity, spriteName)', 'count': 1, 'contract': 'actual command grid square'}, {'old': 'targetFloor:AddTileObject(NewLitterObj)', 'new': 'entity:AddTileObject(NewLitterObj)', 'count': 1, 'contract': 'same exact square owns addition'}]}]), ('LifestyleHobbies', 'media/lua/shared/LSUtil.lua'): ('342b4e37783039f7292e2a67cb9ea4b592c80daa00de38a48bf79b4ba8452b64', 'e0de33fd64a4945d2d7ab2717f12eb4ec6e7c34c1795d214db6e820381307643', [(78762, 78836, b'\tif not character then return false; end\r\n\tlocal weapon = character:getPrimaryHandItem()\r\n\tif LSUtil.isValidWeapon(weapon) then return false; end\r\n')], [{'kind': 'exact-residual-source-owner-repair', 'privateOriginalUnchanged': True, 'changes': [{'old': 'if not character or LSUtil.isValidWeapon(weapon) then return false; end\r\n\tlocal weaponType = WeaponType.getWeaponType(character)\r\n\treturn weaponType and weaponType == WeaponType.UNARMED', 'new': 'if not character then return false; end\r\n\tlocal weapon = character:getPrimaryHandItem()\r\n\tif LSUtil.isValidWeapon(weapon) then return false; end\r\n\tlocal weaponType = WeaponType.getWeaponType(character)\r\n\treturn weaponType and weaponType == WeaponType.UNARMED', 'count': 1, 'contract': 'actual primary-hand validation plus native WeaponType'}]}]), ('LifestyleHobbies', 'media/lua/client/Instruments/NewInstrumentsContextMenu.lua'): ('b9a7da0aee683301d8c9319db3904cba60bd11a3ad21d0d0949eb59ff1a879f4', 'f5bfb86c7f94397a54a51d927913d280e6849b25f833bb6d1b6a67d2b55b0df7', [(22031, 22176, b'\t\t\tLSInstrumentRandomOption(context, false, thisPlayer, playableInstrument, Type, playerlevel, InstrumentIconTexture, learnedTracksData)\r\n'), (22215, 22382, b'\t\tLSInstrumentPlayOptions(context, false, thisPlayer, playableInstrument, Type, playerlevel, InstrumentIconTexture, learnedTracksData, InstrumentTracksDuet)\t\t\r\n'), (23331, 23476, b'\t\t\tLSInstrumentRandomOption(context, false, thisPlayer, playableInstrument, Type, playerlevel, InstrumentIconTexture, learnedTracksData)\r\n'), (23515, 23680, b'\t\tLSInstrumentPlayOptions(context, false, thisPlayer, playableInstrument, Type, playerlevel, InstrumentIconTexture, learnedTracksData, InstrumentTracksDuet)\r\n')], [{'kind': 'exact-residual-source-owner-repair', 'privateOriginalUnchanged': True, 'changes': [{'symbol': 'worldobjects', 'count': 4, 'contract': 'inventory/hotbar has no world-object target; callback first parameter ignored, false matches practice option'}]}]), ('LifestyleHobbies', 'media/lua/client/Instruments/VanillaInstrumentsContextMenu.lua'): ('588e7d95b9bea95096855302d1f4e90cde3984e4f845e75803a9d2d04b85b8fe', 'b79540b62ea50753945665c399fe3c84b2f9c2a1e3cb54e50e922149fce7c0b4', [(22742, 22888, b'\t\t\t\tLSInstrumentRandomOption(context, false, thisPlayer, playableInstrument, Type, playerlevel, InstrumentIconTexture, learnedTracksData)\r\n'), (22988, 23154, b'\t\t\tLSInstrumentPlayOptions(context, false, thisPlayer, playableInstrument, Type, playerlevel, InstrumentIconTexture, learnedTracksData, InstrumentTracksDuet)\r\n'), (25002, 25148, b'\t\t\t\tLSInstrumentRandomOption(context, false, thisPlayer, playableInstrument, Type, playerlevel, InstrumentIconTexture, learnedTracksData)\r\n'), (25740, 25906, b'\t\t\tLSInstrumentPlayOptions(context, false, thisPlayer, playableInstrument, Type, playerlevel, InstrumentIconTexture, learnedTracksData, InstrumentTracksDuet)\r\n')], [{'kind': 'exact-residual-source-owner-repair', 'privateOriginalUnchanged': True, 'changes': [{'symbol': 'worldobjects', 'count': 4, 'contract': 'inventory/hotbar has no world-object target; callback first parameter ignored, false matches practice option'}]}]), ('LifestyleHobbies', 'media/lua/client/Painting/ArtCardContextMenu.lua'): ('69cdde305a16c01475eaf06de5ff9b27d7a5b027b352b5699a33ccc6ad185e5f', '17f810cce89a79e67cf9a54016b4588b44749d0d682b87a516d75458bcd5d2bd', [(6169, 6235, b'local function iceObjDebugOption(context, DebugBuildOption, Art, worldobjects)\r\n'), (7754, 7894, b'\tif LSUtil.hasAdminRights() and customName and (customName == "Sculpture Ice") then iceObjDebugOption(context, DebugBuildOption, Art, worldobjects); end\r\n')], [{'kind': 'exact-residual-source-owner-repair', 'privateOriginalUnchanged': True, 'changes': [{'old': 'local function iceObjDebugOption(context, DebugBuildOption, Art)', 'new': 'local function iceObjDebugOption(context, DebugBuildOption, Art, worldobjects)', 'count': 1, 'contract': 'exact caller world object target'}, {'old': 'iceObjDebugOption(context, DebugBuildOption, Art);', 'new': 'iceObjDebugOption(context, DebugBuildOption, Art, worldobjects);', 'count': 1, 'contract': 'live doBuildMenu target carried to ice callback'}]}])}

def adapt_source_residual_lifestyle(raw, source_id, selected_path):
    spec = RESIDUAL_LIFESTYLE_ADAPTATIONS.get((source_id, selected_path))
    if not spec:
        return raw, []
    before, after, edits, metadata = spec
    assert sha(raw) == before, (source_id, selected_path, "Lifestyle residual preimage drift")
    for start, stop, replacement in reversed(edits):
        raw = raw[:start] + replacement + raw[stop:]
    assert sha(raw) == after, (source_id, selected_path, "Lifestyle residual postimage drift")
    return raw, metadata

# Apply after the existing exact source namespace lifetime adapter.
RESIDUAL_MUSIC_ARCADE_ADAPTATIONS = {('NewMusic', 'media/lua/server/zombies/NMServerZombieVisualTargetPublisher.lua'): ('c470a2df34b8b5c0f9556bea52dc038c5fe81a30b60138c64af77d5ef494a0b4', 'f5305f9623452b5582dd4da6dc302059f6e1f2b6cdcfa333805bd52686e85ab6', [(b'require "zombies/NMZombieDeviceVariantCatalog"', b'require "zombies/NMZombieDeviceVariantCatalog"\nlocal NMZombieVisualTargetLedger = require "zombies/NMZombieVisualTargetLedger"', 1), (b'NMServerZombieVisualTargetLedger', b'NMZombieVisualTargetLedger', 3)], [{'kind': 'source-residual-owner-binding', 'contract': 'exact returned ledger owner', 'privateOriginalUnchanged': True}, {'kind': 'source-residual-owner-binding', 'contract': 'diagnostic owner typo', 'privateOriginalUnchanged': True}]), ('NewMusic', 'media/lua/client/ui/shared/slots/NMMediaSlotLogic.lua'): ('83752c9ac7607ecb1a38a6584d977630b792639ded12273b0d0c01bb91294834', 'bb332a8807aa339a8c72a25cfd6d1120e76db65245ac6695a55818f1b60db965', [(b'    if NMUI and NMUI.logPortableUiProbe then\n        NMUI.logPortableUiProbe(tag, detail)\n    end', b'    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("portable_ui")) then\n        return\n    end\n    NMCore.logChannel("portable_ui", tostring(tag or "portable_ui"), tostring(detail or ""))', 1)], [{'kind': 'source-residual-owner-binding', 'contract': 'existing gated NMCore portable_ui contract', 'privateOriginalUnchanged': True}]), ('NewMusic', 'media/lua/client/ui/NMGamepadRadial.lua'): ('ab9bffafbbef91665cf42d4803529e7c91a731dd40998d2b30ff23294b6db580', 'b5fc33947f2690c9d97205e010c269867029e9c33ffe9b97778ca4d06c0194f8', [(b'local GAMEPAD_TEXTURE_ROOT =', b'local function playWindowSound(ownerName, helperName, window, argument)\n    local owner = rawget(_G, ownerName)\n    local helper = type(owner) == "table" and rawget(owner, helperName) or nil\n    if type(helper) == "function" then helper(window, argument) end\nend\n\nlocal GAMEPAD_TEXTURE_ROOT =', 1), (b'((getLoopPolicy and getLoopPolicy(state)) or (state and state.playbackPolicy) or "autoplay")', b'((state and state.playbackPolicy) or "autoplay")', 1), (b'playWalkmanTransportSound then', b'type(rawget(_G, "NMWalkmanWindowEnv")) == "table" then', 1), (b'playWalkmanTransportSound(window, false)', b'playWindowSound("NMWalkmanWindowEnv", "playWalkmanTransportSound", window, false)', 1), (b'playCDPlayerTransportSound then', b'type(rawget(_G, "NMCDPlayerWindowEnv")) == "table" then', 1), (b'playCDPlayerTransportSound(window, true)', b'playWindowSound("NMCDPlayerWindowEnv", "playCDPlayerTransportSound", window, true)', 1), (b'playCDPlayerRandomBeep then', b'type(rawget(_G, "NMCDPlayerWindowEnv")) == "table" then', 2), (b'playCDPlayerRandomBeep(window)', b'playWindowSound("NMCDPlayerWindowEnv", "playCDPlayerRandomBeep", window)', 2), (b'playCDPlayerManualPlaySound then', b'type(rawget(_G, "NMCDPlayerWindowEnv")) == "table" then', 1), (b'playCDPlayerManualPlaySound(window)', b'playWindowSound("NMCDPlayerWindowEnv", "playCDPlayerManualPlaySound", window)', 1)], [{'kind': 'source-residual-owner-binding', 'contract': 'late exact private helper binding', 'privateOriginalUnchanged': True}, {'kind': 'source-residual-owner-binding', 'contract': 'owned state policy', 'privateOriginalUnchanged': True}, {'kind': 'source-residual-owner-binding', 'contract': 'private owner admission', 'privateOriginalUnchanged': True}, {'kind': 'source-residual-owner-binding', 'contract': 'exact private call recipient', 'privateOriginalUnchanged': True}, {'kind': 'source-residual-owner-binding', 'contract': 'private owner admission', 'privateOriginalUnchanged': True}, {'kind': 'source-residual-owner-binding', 'contract': 'exact private call recipient', 'privateOriginalUnchanged': True}, {'kind': 'source-residual-owner-binding', 'contract': 'private owner admission', 'privateOriginalUnchanged': True}, {'kind': 'source-residual-owner-binding', 'contract': 'exact private call recipient', 'privateOriginalUnchanged': True}, {'kind': 'source-residual-owner-binding', 'contract': 'private owner admission', 'privateOriginalUnchanged': True}, {'kind': 'source-residual-owner-binding', 'contract': 'exact private call recipient', 'privateOriginalUnchanged': True}]), ('NewMusic', 'media/lua/client/ui/shared/host/NMDeviceUiTime.lua'): ('44d13ce5c48bb8ea09390906d5e7f4110800bfef7014b8c42eb81c3dbe23efad', 'e8cae09ac5e0f02ff48035dffd6573f96468360cc0302203b6a3bc86a30376b1', [(b'    if getNowMs then\n        local nowMs = tonumber(getNowMs())\n        if nowMs then\n            return nowMs\n        end\n    end\n', b'', 1)], [{'kind': 'source-residual-owner-binding', 'contract': 'native timestamps, no unrelated/private helper precedence', 'privateOriginalUnchanged': True}]), ('NewMusic', 'media/lua/client/ui/shared/slots/NMSlotHostContextCache.lua'): ('64717b6cf79e4284ba9dde7afbe5467b81f3198a4b2d1a5709edd736362bf664', 'fd587506bba9f5a7e3bdad0b811b94f4aec961ba5f2f8099ec81a89ee3701e43', [(b'local function resolveNowMs()', b'local NMSlotActionCommon = require "ui/shared/slots/NMSlotActionCommon"\n\nlocal function resolveNowMs()', 1), (b'    if resolveDraggedInventoryItemsSnapshot then\n        return resolveDraggedInventoryItemsSnapshot()\n    end\n', b'', 1)], [{'kind': 'source-residual-owner-binding', 'contract': 'complete selected drag owner', 'privateOriginalUnchanged': True}, {'kind': 'source-residual-owner-binding', 'contract': 'private helper is not public drag authority', 'privateOriginalUnchanged': True}]), ('NewMusic', 'media/lua/client/ui/shared/slots/NMSlotHostFrameBuilder.lua'): ('c30e55814d83b6d990c7306e4fa8b667f8f04fa331279c56fc792238fbebac02', '8fb2517fab9143e56472fd0822b4cbc0c86926379dfcb7cb0dc8ed052362811b', [(b'local function resolveNowMs()', b'local NMSlotActionCommon = require "ui/shared/slots/NMSlotActionCommon"\n\nlocal function resolveNowMs()', 1), (b'    if resolveDraggedInventoryItemsSnapshot then\n        return resolveDraggedInventoryItemsSnapshot()\n    end\n', b'', 1)], [{'kind': 'source-residual-owner-binding', 'contract': 'complete selected drag owner', 'privateOriginalUnchanged': True}, {'kind': 'source-residual-owner-binding', 'contract': 'private helper is not public drag authority', 'privateOriginalUnchanged': True}]), ('NewMusic', 'media/lua/client/ui/shared/slots/NMBatterySlotLogic.lua'): ('7d6c76fb517fb4186acdc31a337f614f804b2d163804e0bd638a2d67b23acde5', '22be443aa56bbfbfb64f34e38b7574d381c248227a3aa12dd7ac14551740830b', [(b'    local mouseOver = isMouseOverButton(button)\n    if fullType == "" and timed == nil', b'    local mouseOver = isMouseOverButton(button)\n    local timed = window and window._nmBatterySlotTimedProgress or nil\n    if fullType == "" and timed == nil', 1)], [{'kind': 'source-residual-owner-binding', 'contract': 'call-owned timed progress', 'privateOriginalUnchanged': True}]), ('ProjectArcade', 'media/lua/client/TimedActions/ProjectArcade_PlayArcadeTimedAction.lua'): ('95f7b1c53924ca971b8f2f0f6cf43f956a94772e50f80a8f112ae849b0563d01', 'b4e50467e2e5ef0ac12086f4820cacefc86a179bba5f08b6ce5bf324eba3aff0', [(b'require "ProjectArcade_Currency"', b'require "ProjectArcade_Currency"\nlocal ArcadeAmbientSound = require "ProjectArcade_ArcadeAmbientSound"\nlocal ArcadeSoundPolicy = require "ProjectArcade_SoundPolicy"', 1), (b'local function getLoopDurationMs(soundName)\n    if soundName == "PAMsfplay" then return 46000 end\n    if soundName == "PAMdroidsplay" then return 30000 end\n    if soundName == "PAMpinballplay" then return 29000 end\n    if soundName == "PAddplay" then return 58000 end\n\tif soundName == "PAsiplay" then return 38000 end \n    if soundName == "PAafplay" then return 50000 end\n    if soundName == "PAtzplay" then return 53000 end\n    if soundName == "PAijplay" then return 60500 end\n\tif soundName == "PAdkplay" then return 55000 end\n    if soundName == "PAt2play" then return 60000 end\n    if soundName == "PAcenplay" then return 60000 end\n    if soundName == "PAdigplay" then return 64000 end\n    if soundName == "PAnbaplay" then return 62000 end\n    if soundName == "PAtmntplay" then return 62000 end\n    if soundName == "PAmkplay" then return 60000 end\n    if soundName == "PAfhplay" then return 60000 end\n    if soundName == "PAbk2000play" then return 70000 end\n    if soundName == "PAetpmplay" then return 60000 end\n    if soundName == "PAswplay" then return 60000 end\n    if soundName == "PAmbplay" then return 60000 end\n\n    return 25000\nend', b'local getLoopDurationMs = ArcadeSoundPolicy.getLoopDurationMs', 1)], [{'kind': 'source-residual-owner-binding', 'contract': 'returned ambient and duration module owners', 'privateOriginalUnchanged': True}, {'kind': 'source-residual-owner-binding', 'contract': 'same original durations used in every consumer', 'privateOriginalUnchanged': True}]), ('ProjectArcade', 'media/lua/client/ProjectArcade_WorldSoundsClient.lua'): ('13b5f4813934470d7c7475485076a473844220b0bdcd17614d163b80bece465c', '84f645881e999de53d86eafc62f39b1a378a066d1c106ad8d8f6ea7c94f7929a', [(b'if not isClient() then return end', b'if not isClient() then return end\nlocal ArcadeSoundPolicy = require "ProjectArcade_SoundPolicy"', 1), (b'                            local dur = 60000\r\n                            if getLoopDurationMs then dur = getLoopDurationMs(e.sound) or dur end', b'                            local dur = ArcadeSoundPolicy.getLoopDurationMs(e.sound)', 1)], [{'kind': 'source-residual-owner-binding', 'contract': 'selected shared duration module', 'privateOriginalUnchanged': True}, {'kind': 'source-residual-owner-binding', 'contract': 'exact original clip duration scheduling', 'privateOriginalUnchanged': True}]), ('ProjectArcade', 'media/lua/client/ProjectArcade_PunchingMachine.lua'): ('2657e189d8cb148b4a5c8181d5debb8f8b809ee8fd7d2af29bcef0301d5e4974', 'e4dc8ce777caa6ecadb9ca68ac9293ace6d79bd6b0ca4248ec671e7e613471bd', [(b'local function safeGetText', b'local function PA_GetSfxVolMult()\r\n    local pct = 100\r\n    if SandboxVars and SandboxVars.ProjectArcade and SandboxVars.ProjectArcade.SfxVolumePct ~= nil then\r\n        pct = tonumber(SandboxVars.ProjectArcade.SfxVolumePct) or 100\r\n    end\r\n    if pct < 0 then pct = 0 end\r\n    if pct > 100 then pct = 100 end\r\n    return pct / 100.0\r\nend\r\n\r\nlocal function PA_PlayOneShotAtCharacter(character, soundName)\r\n    if not soundName then return end\r\n\r\n    local snd = GameSounds and GameSounds.getSound and GameSounds.getSound(soundName)\r\n    if not snd then return end\r\n\r\n    local clip = snd:getRandomClip()\r\n    if not clip then return end\r\n\r\n    local e = IsoWorld.instance:getFreeEmitter()\r\n    e:setPos(character:getX(), character:getY(), character:getZ())\r\n\r\n    local id = e:playClip(clip, nil)\r\n    if id and id ~= 0 then\r\n        e:setVolume(id, 1.0 * PA_GetSfxVolMult())\r\n        e:set3D(id, true)\r\n        e:tick()\r\n    end\r\nend\r\n\r\nlocal function safeGetText', 1)], [{'kind': 'source-residual-owner-binding', 'contract': 'exact existing SP helper made lexical in MP recipient callback; no new event', 'privateOriginalUnchanged': True}]), ('ProjectArcade', 'media/lua/client/ProjectArcade_PAMPlayGameMenu.lua'): ('13440dd1069d5145e920fdca5446dc9a6fa4e2b0a3d745b6aaaa1bdda3f635e0', '475e50585687daf64ee99cb4ee424b81482427b4b43d3bcfc569d0e696f83952', [(b'getText("ContextMenu_PlayPinball") or safeGetText("ContextMenu_PlayPinball")', b'getText("ContextMenu_PlayPinball") or "ContextMenu_PlayPinball"', 1), (b'getText("ContextMenu_PlayArcade") or safeGetText("ContextMenu_PlayArcade")', b'getText("ContextMenu_PlayArcade") or "ContextMenu_PlayArcade"', 2)], [{'kind': 'source-residual-owner-binding', 'contract': 'native locale key fallback', 'privateOriginalUnchanged': True}, {'kind': 'source-residual-owner-binding', 'contract': 'native locale key fallback', 'privateOriginalUnchanged': True}]), ('ProjectArcade', 'media/lua/server/ProjectArcade_RecipeBridge.lua'): ('a8deeb50bf9ba665305c691d07af9348bdff9f6a1823e8a17e61f7a98eeb296a', 'f2dceadab55f6247af8273ccbe3ae608d4faa6c33d4495de225c877ec0ffd967', [(b'"NeatBuilding"', b'"Neat_Building"', 1)], [{'kind': 'source-residual-owner-binding', 'contract': 'actual installed provider mod id', 'privateOriginalUnchanged': True}]), ('ProjectArcade', 'media/lua/server/ProjectArcade_NB_Compat.lua'): ('966abf8fc83ad2f02110df84cbb209357a85c589b3c28679326b4042aaa5aa5e', '768c4b2bc22ce89bd597a1ce61ea29066e3109ed6858eae7bb1b481778cd0ac9', [(b'Events.OnGameBoot.Add(function()', b'local function applyNBCompat()', 1), (b'end)\r\n', b'end\r\nEvents.OnGameBoot.Add(applyNBCompat)\r\nEvents.OnGameStart.Add(applyNBCompat)\r\n', 1), (b'"NeatBuilding"', b'"Neat_Building"', 1), (b'    _G.ProjectArcade_NBCompatPatched = true\r\n\r\n', b'', 1), (b'        local original = NB_BuildRecipeCode.Floors.OnCreate', b'        _G.ProjectArcade_NBCompatPatched = true\r\n        local original = NB_BuildRecipeCode.Floors.OnCreate', 1)], [{'kind': 'source-residual-owner-binding', 'contract': 'one patch owner, retried at native game-start boundary', 'privateOriginalUnchanged': True}, {'kind': 'source-residual-owner-binding', 'contract': 'later provider admission through existing native events', 'privateOriginalUnchanged': True}, {'kind': 'source-residual-owner-binding', 'contract': 'actual installed provider mod id', 'privateOriginalUnchanged': True}, {'kind': 'source-residual-owner-binding', 'contract': 'absence never consumes patch admission', 'privateOriginalUnchanged': True}, {'kind': 'source-residual-owner-binding', 'contract': 'once-only admission after complete provider', 'privateOriginalUnchanged': True}]), ('ProjectArcade', 'media/lua/client/InventoryTetris/DataPacks/Mods/TetrisDataPack_ProjectArcade.lua'): ('87a75c4da4f6ee17ba08553777b809eed9809e5c78eabbda8072472c224cfd89', '7abfd6b1f0259418aea3c1f8ffc022d5f5c18996bff0a693080574aa49753e94', [(b'\tif not TetrisItemData then return end', b'\tif not (type(TetrisItemData) == "table" and type(TetrisItemData.registerItemDefinitions) == "function"\n        and type(TetrisContainerData) == "table" and type(TetrisContainerData.registerContainerDefinitions) == "function"\n        and type(TetrisPocketData) == "table" and type(TetrisPocketData.registerPocketDefinitions) == "function") then return end', 1)], [{'kind': 'source-residual-owner-binding', 'contract': 'atomic optional complete method-shape admission', 'privateOriginalUnchanged': True}]), ('ProjectArcade', 'media/lua/server/ProjectArcade_PunchingServer.lua'): ('254769c0251f45d592d71b312be5f3b91842e41a433339c9a5bc6cb82b52b2d5', '6caf3f6910037a2353c9e1c5ab0d253100fb3bd8e3c983b047a13af78108496a', [(b'    if isSinglePlayer then\n        return not isSinglePlayer()\n    end\n    return true', b'    return isServer() == true', 1)], [{'kind': 'source-residual-owner-binding', 'contract': 'actual native server predicate; no unowned hook', 'privateOriginalUnchanged': True}])}

def adapt_source_residual_music_arcade(raw, source_id, selected_path):
    spec = RESIDUAL_MUSIC_ARCADE_ADAPTATIONS.get((source_id, selected_path))
    if not spec:
        return raw, []
    preimage, postimage, edits, metadata = spec
    if sha(raw) != preimage:
        raise ValueError('Residual music/arcade preimage changed: ' + source_id + ':' + selected_path)
    content = raw
    for old, new, count in edits:
        if content.count(old) != count:
            raise ValueError('Residual music/arcade exact occurrence changed: ' + selected_path)
        content = content.replace(old, new)
    if sha(content) != postimage:
        raise ValueError('Residual music/arcade postimage changed: ' + source_id + ':' + selected_path)
    return content, [dict(row) for row in metadata]

ARCADE_SHARED_DURATION_POLICY = b'-- Derived from ProjectArcade selected duration policy; original source remains in SAOSources.\nrequire "SAO_SourceIntegration"\nif not SAO.SourceIntegration.active("ProjectArcade") then return end\nlocal Policy = {}\nfunction Policy.getLoopDurationMs(soundName)\n    if soundName == "PAMsfplay" then return 46000 end\n    if soundName == "PAMdroidsplay" then return 30000 end\n    if soundName == "PAMpinballplay" then return 29000 end\n    if soundName == "PAddplay" then return 58000 end\n\tif soundName == "PAsiplay" then return 38000 end \n    if soundName == "PAafplay" then return 50000 end\n    if soundName == "PAtzplay" then return 53000 end\n    if soundName == "PAijplay" then return 60500 end\n\tif soundName == "PAdkplay" then return 55000 end\n    if soundName == "PAt2play" then return 60000 end\n    if soundName == "PAcenplay" then return 60000 end\n    if soundName == "PAdigplay" then return 64000 end\n    if soundName == "PAnbaplay" then return 62000 end\n    if soundName == "PAtmntplay" then return 62000 end\n    if soundName == "PAmkplay" then return 60000 end\n    if soundName == "PAfhplay" then return 60000 end\n    if soundName == "PAbk2000play" then return 70000 end\n    if soundName == "PAetpmplay" then return 60000 end\n    if soundName == "PAswplay" then return 60000 end\n    if soundName == "PAmbplay" then return 60000 end\n\n    return 25000\nend\nreturn Policy\n'

def derive_arcade_shared_duration_policy(action_preimage):
    # Source metadata pins the original action; this input is its existing derived runtime preimage.
    if sha(action_preimage) != '95f7b1c53924ca971b8f2f0f6cf43f956a94772e50f80a8f112ae849b0563d01':
        raise ValueError('Arcade shared duration source preimage changed')
    if sha(ARCADE_SHARED_DURATION_POLICY) != '4d30e5328b125f631c71686ff1aa7377f2e4fe94303371c0ad9d3aa513253442':
        raise ValueError('Arcade shared duration policy postimage changed')
    return ARCADE_SHARED_DURATION_POLICY, {'path': 'shared/ProjectArcade_SoundPolicy.lua', 'sourceId': 'ProjectArcade', 'postimageSha256': '4d30e5328b125f631c71686ff1aa7377f2e4fe94303371c0ad9d3aa513253442', 'derivedFrom': 'client/TimedActions/ProjectArcade_PlayArcadeTimedAction.lua', 'derivedFromSha256': '95f7b1c53924ca971b8f2f0f6cf43f956a94772e50f80a8f112ae849b0563d01', 'exactOriginalFragmentSha256': 'b121ed65d58d3c55bc93035d04ccb7fc431d77d7911854b65eaa3db4fecd189d', 'ownership': 'single returned immutable duration policy; no event/emitter/state producer'}


SAO_OWNED_REPLACEMENTS = {
    ('LifestyleHobbies', 'media/lua/client/DJBoothContextMenu.lua'): {
        'sourceSha256': '8894fd69dcf5326dfd740d36b26c4fc95f2b1f7c01fdd6dd3e2b54e45256fa93',
        'destinationSha256': 'afcd7fcd5c83d94f8c88a90f108f9870183c761748f770456138c5b0f5452764',
        'adaptations': [{'kind': 'sao-owned-player-dj-menu', 'sourceOriginalPreserved': True,
                         'qualifiedBy': 'tools/d2_player_dj_menu_test.py',
                         'qualifiedReceipt': '_scratch/d2-leisure-01/participant-integration21/native-play04/resolution12/player-dj-menu54/receipt.json',
                         'qualifiedReceiptSha256': '64dab132105d59247165e61007b3f6bf888cca4a7d95578b10fa7198156b5038'}],
    },
    ('LifestyleHobbies', 'media/lua/shared/TimedActions/PlayDJBoothAction.lua'): {
        'sourceSha256': '6a8d3dd5767260e67ea96353a197ce577a3a023ccc7e2fd56151a2a8f55e7dac',
        'destinationSha256': 'd479950698ce14da1af7f04c3d5d8511c18627aabc43fc63333de0ecfb5cec69',
        'adaptations': [{'kind': 'sao-owned-player-dj-action', 'sourceOriginalPreserved': True,
                         'qualifiedBy': 'tools/d2_player_dj_action_test.py',
                         'qualifiedReceipt': '_scratch/d2-leisure-01/participant-integration21/native-play04/resolution12/player-dj-action53/receipt.json',
                         'qualifiedReceiptSha256': '5a27797004461243fb9cec93f28f8d2ce9541b15ab028141d7d11df48ac25ff7'}],
    },
}


def preserve_owned_replacement(mod: Path, sealed_manifest: dict | None, source_id: str,
                               selected_path: str, source_sha: str,
                               adapted: bytes, adaptations: list[dict]) -> tuple[bytes, list[dict]]:
    """Reuse an independently qualified destination only under its exact source seal."""
    key = (source_id, selected_path)
    pin = SAO_OWNED_REPLACEMENTS.get(key)
    if pin is None or sealed_manifest is None:
        return adapted, adaptations
    rows = [row for row in sealed_manifest.get('files', [])
            if (row.get('sourceId'), row.get('selectedPath')) == key]
    if not rows:
        return adapted, adaptations
    if len(rows) != 1:
        raise ValueError('SAO-owned replacement has ambiguous manifest rows: ' + selected_path)
    row = rows[0]
    if row.get('adaptations') != pin['adaptations']:
        # A pre-rewrite manifest still plans its own generic adapted output.
        if not any(a.get('kind', '').startswith('sao-owned-player-dj-')
                   for a in row.get('adaptations', [])):
            return adapted, adaptations
        raise ValueError('SAO-owned replacement qualification changed: ' + selected_path)
    if source_sha != pin['sourceSha256'] or row.get('sourceSha256') != source_sha:
        raise ValueError('SAO-owned replacement source changed: ' + selected_path)
    if row.get('destination') != selected_path or row.get('destinationSha256') != pin['destinationSha256']:
        raise ValueError('SAO-owned replacement destination pin changed: ' + selected_path)
    original = mod / 'media/SAOSources' / source_id / selected_path
    destination = mod / selected_path
    if not original.is_file() or sha(original.read_bytes()) != source_sha:
        raise ValueError('SAO-owned replacement private original changed: ' + selected_path)
    if not destination.is_file():
        raise ValueError('SAO-owned replacement destination missing: ' + selected_path)
    content = destination.read_bytes()
    if sha(content) != pin['destinationSha256']:
        raise ValueError('SAO-owned replacement destination changed: ' + selected_path)
    return content, list(pin['adaptations'])


def build_plan(workshop: Path, mod: Path) -> tuple[dict, dict[str, bytes], list[dict]]:
    sealed_path = mod / 'media/SAOSources/manifest.json'
    sealed_manifest = json.loads(sealed_path.read_text(encoding='utf-8')) if sealed_path.is_file() else None
    manifest = {"schema": "sao.owned-source-package/1", "packageId": "SurvivorAwareness", "sources": {}, "files": [], "overrides": [], "mergeRequired": [], "publicationLimits": [], "scope": "D2 leisure shared native source mechanics and assets; SAO retains person ownership"}
    outputs: dict[str, bytes] = {}
    collisions = []
    translations: dict[str, tuple[dict, str]] = {}
    translation_sources: dict[str, list[str]] = {}
    for source_id, (relative_root, version, author, terms) in SOURCES.items():
        root = workshop / relative_root
        if not root.is_dir():
            raise ValueError(f"missing required installed root: {root}")
        selected, overrides = overlay(root, version)
        manifest["overrides"].extend({"sourceId": source_id, **entry} for entry in overrides)
        info = root / version / "mod.info"
        if not info.is_file():
            raise ValueError(f"missing selected metadata: {info}")
        info_text = info.read_text(encoding="utf-8-sig")
        registrations = [line.strip() for line in info_text.splitlines() if line.startswith(("pack=", "tiledef=", "require="))]
        source = {"sourceId": source_id, "workshopRoot": relative_root, "payload": version, "author": author, "terms": terms, "registrations": registrations, "metadataSha256": sha(info.read_bytes()), "originalRoot": "media/SAOSources/" + source_id, "sentinel": "media/SAOSources/" + source_id + "/package.txt"}
        manifest["sources"][source_id] = source
        metadata = {info: "selected-mod.info"}
        for entry in root.iterdir():
            if entry.is_file() and any(word in entry.name.lower() for word in ("readme", "credit", "license", "licence", "copyright")):
                metadata[entry] = entry.name
        source['provenance'] = []
        for original, name in metadata.items():
            destination = source["originalRoot"] + "/provenance/" + name
            outputs[destination] = original.read_bytes()
            source['provenance'].append({'sourcePath':str(original),'destination':destination,'sha256':sha(outputs[destination])})
        source_rows = []
        for relative, original in selected.items():
            raw = original.read_bytes()
            source_sha = sha(raw)
            is_lua = relative.startswith("media/lua/") and relative.endswith(".lua")
            # Translation data is engine data, not a runnable Lua module.
            runnable = is_lua and "/Translate/" not in relative
            if relative.startswith("media/lua/"):
                outputs[source["originalRoot"] + "/" + relative] = raw
            destination = relative
            content, adaptations = adapt_lua(raw, source_id) if runnable else (raw, [])
            if source_id == "LifestyleHobbies" and runnable:
                content, physical_adaptations = adapt_lifestyle_physical_owner(content, relative)
                adaptations.extend(physical_adaptations)
                content, locale_adaptations = adapt_lifestyle_native_locale(content, relative)
                adaptations.extend(locale_adaptations)
                content, callback_adaptations = adapt_lifestyle_callback_bindings(content, relative)
                adaptations.extend(callback_adaptations)
                content, interval_adaptations = adapt_lifestyle_sound_interval(content, relative)
                adaptations.extend(interval_adaptations)
                content, utility_adaptations = adapt_lifestyle_utility_bindings(content, relative)
                adaptations.extend(utility_adaptations)
                content, invention_adaptations = adapt_lifestyle_invention_bindings(content, relative)
                adaptations.extend(invention_adaptations)
                content, temporary_adaptations = adapt_lifestyle_temporaries(content, relative)
                content, lifetime_adaptations = adapt_lifestyle_state_lifetimes(content, relative)
                adaptations.extend(lifetime_adaptations)
                adaptations.extend(temporary_adaptations)
            if source_id == "ProjectArcade":
                content, text_adaptations = adapt_arcade_punching_text(content, relative)
                adaptations.extend(text_adaptations)
            if source_id == "NewMusic" and runnable:
                content, diagnostic_adaptations = adapt_newmusic_loot_diagnostic(content, relative)
                adaptations.extend(diagnostic_adaptations)
                content, context_adaptations = adapt_newmusic_track_finished_context(content, relative)
                adaptations.extend(context_adaptations)
            if runnable:
                content, namespace_adaptations = adapt_source_namespace_lifetimes(content, source_id, relative)
                adaptations.extend(namespace_adaptations)
                derived_policy = None
                content, residual_adaptations = adapt_source_residual_lifestyle(content, source_id, relative)
                adaptations.extend(residual_adaptations)
                if source_id == "ProjectArcade" and relative == "media/lua/client/TimedActions/ProjectArcade_PlayArcadeTimedAction.lua":
                    derived_policy = derive_arcade_shared_duration_policy(content)
                content, residual_adaptations = adapt_source_residual_music_arcade(content, source_id, relative)
                adaptations.extend(residual_adaptations)
            content, adaptations = preserve_owned_replacement(
                mod, sealed_manifest, source_id, relative, source_sha, content, adaptations)
            if source_id == "NewMusic" and relative == "media/lua/client/timedactions/NMDisassembleDeviceAction.lua":
                destination = "media/lua/client/TimedActions/NMDisassembleDeviceAction.lua"
                adaptations.append({"kind": "native-timed-action-directory-case", "original": relative})
            if source_id == "FWOBenchPressTreadmill" and relative in {"media/lua/client/FWOScript.lua", "media/lua/server/FWOScript.lua"}:
                destination = relative.replace("FWOScript.lua", "FWOEquipmentScript.lua")
                adaptations.append({"kind": "distinct-source-initializer-module-name", "original": relative})
            if "/Translate/" in relative and Path(relative).name == "Mod.json":
                # Source product metadata remains provenance; the delivered
                # product's translated name/description stays canonical SAO.
                destination = source["originalRoot"] + "/" + relative
                content = raw
                adaptations = [{"kind": "source-product-metadata-provenance"}]
            elif ("/Translate/" in relative and
                  (relative.endswith('.json') or relative in outputs or (mod / relative).is_file()) and
                  not (relative not in translations and relative not in outputs and
                       (mod / relative).is_file() and (mod / relative).read_bytes() == raw)):
                if relative not in translations and (mod / relative).is_file():
                    translations[relative] = parse_translation((mod / relative).read_bytes(), relative)
                elif relative not in translations and relative in outputs:
                    translations[relative] = parse_translation(outputs[relative], relative)
                    del outputs[relative]
                incoming, wrapper = parse_translation(raw, relative)
                if source_id == "LifestyleHobbies":
                    incoming, _ = adapt_lifestyle_locale_values(incoming, relative)
                if relative in translations:
                    prior_values, prior_wrapper = translations[relative]
                    for key, value in incoming.items():
                        if key in prior_values and prior_values[key] != value:
                            collisions.append({"path": relative, "sourceId": source_id, "kind": "translation-key-value-conflict", "key": key, "previous": prior_values[key], "incoming": value})
                        else:
                            prior_values[key] = value
                    translations[relative] = prior_values, prior_wrapper
                else:
                    translations[relative] = incoming, wrapper
                translation_sources.setdefault(relative, []).append(source_id)
                destination = "media/SAOSources/Merged/" + relative
                content = serialize_translation(*translations[relative], relative)
                outputs[destination] = content
                adaptations = [{"kind": "merged-translation-namespace", "enginePath": relative}]
            prior = outputs.get(destination)
            existing = mod / destination
            # Global engine concatenation files require the canonical owner to
            # merge namespaces; never replace that owner's existing file.
            if destination in {"media/sandbox-options.txt", "media/tileGeometry.txt", "media/tileDepthTextureAssignments.txt", "media/perks.txt", "media/registries.lua", "media/fileGuidTable.xml"}:
                fragment = source["originalRoot"] + "/registration/" + Path(relative).name
                outputs[fragment] = raw
                manifest["mergeRequired"].append({"sourceId": source_id, "enginePath": relative, "fragment": fragment, "sha256": source_sha})
                destination = fragment
                content = raw
                adaptations = []
            elif prior is not None and prior != content and "/Translate/" not in relative:
                collisions.append({"path": destination, "sourceId": source_id, "kind": "between-source-payloads", "previousSha256": sha(prior), "incomingSha256": sha(content)})
            elif existing.is_file() and existing.read_bytes() != content:
                collisions.append({"path": destination, "sourceId": source_id, "kind": "owned-existing-destination", "previousSha256": sha(existing.read_bytes()), "incomingSha256": sha(content)})
            outputs[destination] = content
            row = {"sourceId": source_id, "sourcePath": str(original), "selectedPath": relative, "sourceSha256": source_sha, "destination": destination, "destinationSha256": sha(content), "bytes": len(content), "kind": "runtime-lua" if runnable else "asset-or-data", "adaptations": adaptations, "termsRecord": source["originalRoot"] + "/provenance"}
            source_rows.append(row)
            if runnable and derived_policy:
                policy, derived = derived_policy
                policy_path = "media/lua/" + derived["path"]
                if policy_path in outputs or ((mod / policy_path).is_file() and (mod / policy_path).read_bytes() != policy):
                    raise ValueError("Derived Arcade duration destination collision")
                outputs[policy_path] = policy
                source_rows.append(dict(row, destination=policy_path, destinationSha256=sha(policy), bytes=len(policy),
                    adaptations=[{"kind": "source-derived-returned-duration-policy", **derived}],
                    derivedFrom={"selectedPath": relative, "runtimePreimageSha256": derived["derivedFromSha256"],
                                 "fragmentSha256": derived["exactOriginalFragmentSha256"]}))
            if len(content) > 100 * 1024 * 1024:
                manifest["publicationLimits"].append({"path": destination, "bytes": len(content), "reason": "exceeds ordinary GitHub 100MiB object limit"})
        manifest["files"].extend(source_rows)
    for relative, (values, wrapper) in translations.items():
        fragment = "media/SAOSources/Merged/" + relative
        outputs[fragment] = serialize_translation(values, wrapper, relative)
        manifest["mergeRequired"].append({"sourceIds": translation_sources[relative], "enginePath": relative, "fragment": fragment, "sha256": sha(outputs[fragment]), "kind": "merged-translation"})
    for row in manifest["files"]:
        if row["selectedPath"] in translations:
            row["destination"] = "media/SAOSources/Merged/" + row["selectedPath"]
            row["adaptations"] = [{"kind": "merged-translation-namespace", "enginePath": row["selectedPath"]}]
            if row["sourceId"] == "LifestyleHobbies" and row["selectedPath"] in LIFESTYLE_LOCALE_COMPATIBILITY:
                _, locale_adaptations = adapt_lifestyle_locale_values({}, row["selectedPath"])
                row["adaptations"].extend(locale_adaptations)
        row["destinationSha256"] = sha(outputs[row["destination"]])
        row["bytes"] = len(outputs[row["destination"]])
    for source_id, source in manifest["sources"].items():
        source_rows = [row for row in manifest["files"] if row["sourceId"] == source_id]
        seal = sha(json.dumps(source_rows, sort_keys=True, separators=(",", ":")).encode())
        source["seal"] = seal
        outputs[source["sentinel"]] = ("SAO-OWNED-SOURCE/1 " + source_id + " " + seal + "\n").encode()
    registry = ['-- Generated by tools/d2_source_package.py; exact installed source provenance retained.', 'SAO=SAO or {}', 'SAO.SourcePackageManifest={schema="sao.owned-source-package/1",packageId="SurvivorAwareness",sources={']
    for source_id, row in manifest["sources"].items():
        registry.append('[' + lua_quote(source_id) + ']={sentinel=' + lua_quote(row["sentinel"]) + ',seal=' + lua_quote(row["seal"]) + ',root=' + lua_quote(row["originalRoot"]) + '},')
    registry.extend(['}}', 'return SAO.SourcePackageManifest', ''])
    outputs['media/lua/shared/SAO_SourcePackageManifest.lua'] = '\n'.join(registry).encode()
    outputs['media/SAOSources/manifest.json'] = (json.dumps(manifest, indent=2, ensure_ascii=False) + '\n').encode()
    return manifest, outputs, collisions


def parse_translation(raw: bytes, path: str) -> tuple[dict, str]:
    text = raw.decode('utf-16') if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else raw.decode('utf-8-sig')
    if path.endswith('.json'):
        # Original ProjectArcade flat dictionaries carry trailing commas;
        # native keys/values are retained while producing strict JSON.
        return json.loads(re.sub(r',\s*}\s*$', '\n}', text)), ''
    if not path.endswith('.txt'):
        # JSON formatting catalogues have only JSON files; unexpected formats
        # must be assessed rather than silently omitted.
        raise ValueError(f'unsupported translation format: {path}')
    wrapper = re.search(r'^\s*([A-Za-z0-9_]+)\s*=\s*\{', text)
    if not wrapper:
        raise ValueError(f'missing native translation table: {path}')
    values = {}
    matches = list(re.finditer(r'^\s*([A-Za-z0-9_]+)\s*=\s*(.+?)\s*,?\s*$', text, re.M))
    for match in matches:
        if match.group(1) != wrapper.group(1):
            values[match.group(1)] = match.group(2).rstrip(',').strip()
    return values, wrapper.group(1)


def serialize_translation(values: dict, wrapper: str, path: str) -> bytes:
    if path.endswith('.json'):
        return (json.dumps(values, indent=2, ensure_ascii=False) + '\n').encode()
    return (wrapper + ' = {\n' + ''.join(f'    {key} = {value},\n' for key,value in values.items()) + '}\n').encode()


def validate_owned(mod: Path) -> dict:
    manifest_path = mod / 'media/SAOSources/manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    checked = {}
    errors = []
    originals = set()
    for row in manifest['files']:
        destination = row['destination']
        if destination not in checked:
            path = mod / destination
            checked[destination] = sha(path.read_bytes()) if path.is_file() else None
        if checked[destination] != row['destinationSha256']:
            errors.append({'kind': 'owned-runtime-or-asset-mismatch', 'path': destination})
        if row['selectedPath'].startswith('media/lua/'):
            original = manifest['sources'][row['sourceId']]['originalRoot'] + '/' + row['selectedPath']
            if original not in checked:
                path = mod / original
                checked[original] = sha(path.read_bytes()) if path.is_file() else None
            if checked[original] != row['sourceSha256']:
                errors.append({'kind': 'owned-original-mismatch', 'path': original})
            originals.add(original)
    for id, source in manifest['sources'].items():
        for record in source.get('provenance',[]):
            path=mod/record['destination']
            if not path.is_file() or sha(path.read_bytes()) != record['sha256']:
                errors.append({'kind':'owned-provenance-mismatch','path':record['destination']})
        rows = [row for row in manifest['files'] if row['sourceId'] == id]
        seal = sha(json.dumps(rows, sort_keys=True, separators=(',', ':')).encode())
        sentinel = mod / source['sentinel']
        if seal != source['seal'] or not sentinel.is_file() or sentinel.read_bytes() != ('SAO-OWNED-SOURCE/1 ' + id + ' ' + seal + '\n').encode():
            errors.append({'kind': 'owned-source-seal-mismatch', 'sourceId': id})
    return {'schema': 'sao.source-package-integrity/1', 'status': 'PASS' if not errors else 'FAIL', 'sourceCount': len(manifest['sources']), 'sourceRows': len(manifest['files']), 'distinctCheckedFiles': len(checked), 'originalTextRows': len(originals), 'selectedSourceRows': sum(not row.get('derivedFrom') for row in manifest['files']), 'derivedRuntimeRows': sum(bool(row.get('derivedFrom')) for row in manifest['files']), 'manifestSha256': sha(manifest_path.read_bytes()), 'errors': errors}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--workshop', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/workshop/content/108600'))
    parser.add_argument('--mod', type=Path, default=Path(__file__).resolve().parents[1] / 'mod/42.20')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--materialize', action='store_true')
    parser.add_argument('--verify', action='store_true')
    parser.add_argument('--refresh-provenance', action='store_true')
    args = parser.parse_args()
    if args.refresh_provenance:
        path=args.mod/'media/SAOSources/manifest.json'
        manifest=json.loads(path.read_text(encoding='utf-8'))
        count=0
        for id,source in manifest['sources'].items():
            root=args.workshop/source['workshopRoot']
            original_info=root/source['payload']/'mod.info'
            metadata={original_info:'selected-mod.info'}
            for entry in root.iterdir():
                if entry.is_file() and any(word in entry.name.lower() for word in ('readme','credit','license','licence','copyright')):
                    metadata[entry]=entry.name
            records=[]
            for original,name in metadata.items():
                relative=source['originalRoot']+'/provenance/'+name
                owned=args.mod/relative
                if not owned.is_file() or owned.read_bytes()!=original.read_bytes():
                    raise ValueError(f'changed or missing provenance: {owned}')
                records.append({'sourcePath':str(original),'destination':relative,'sha256':sha(owned.read_bytes())})
            source['provenance']=records
            count+=len(records)
        path.write_bytes((json.dumps(manifest,indent=2,ensure_ascii=False)+'\n').encode())
        report={'status':'PROVENANCE_SEALED','sourceCount':len(manifest['sources']),'provenanceFiles':count,'manifestSha256':sha(path.read_bytes())}
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
        print(json.dumps(report,indent=2));return 0
    if args.verify:
        report = validate_owned(args.mod)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        print(json.dumps(report, indent=2))
        return 0 if report['status'] == 'PASS' else 1
    manifest, outputs, collisions = build_plan(args.workshop, args.mod)
    report = {'schema': 'sao.source-package-import/1', 'status': 'COLLISIONS_REFUSED' if collisions else 'PLANNED', 'sourceCount': len(manifest['sources']), 'selectedFiles': len(manifest['files']), 'outputFiles': len(outputs), 'outputBytes': sum(map(len, outputs.values())), 'collisions': collisions, 'mergeRequired': manifest['mergeRequired'], 'registrations': {source_id: row['registrations'] for source_id,row in manifest['sources'].items()}, 'publicationLimits': manifest['publicationLimits']}
    if args.materialize and not collisions:
        for relative, content in outputs.items():
            destination = args.mod / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            if not destination.exists():
                destination.write_bytes(content)
            elif destination.read_bytes() != content:
                raise ValueError(f'changed destination after planning: {destination}')
        report['status'] = 'MATERIALIZED_REGISTRATION_MERGES_PENDING'
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k,v in report.items() if k not in {'mergeRequired','registrations','collisions'}}, indent=2))
    if collisions:
        print(json.dumps(collisions[:30], indent=2))
    return 1 if collisions else 0


if __name__ == '__main__':
    raise SystemExit(main())
