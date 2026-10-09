"""Exact isolated NPC adaptations of the installed art action and selection cores."""
from pathlib import Path
from native_proof_preflight import installed_path
import os,hashlib
SOURCE=installed_path(os.environ.get('LIFESTYLE_LUA',r'C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3403870858\mods\Lifestyle\common\media\lua'))
ACTION_FILES={'canvas':'shared/TimedActions/LSCanvasPaintingAction.lua','sculpture':'shared/TimedActions/LSSculptingAction.lua','appraise':'shared/TimedActions/LSCanvasAppraiseAction.lua'}
MENU_FILES={'canvas':'client/Painting/EaselCanvasContextMenu.lua','sculpture':'client/Painting/Sculpting/SculptingWorkContextMenu.lua'}
EXTRA=['shared/LSUtil.lua','shared/LSSync.lua','shared/Art/ArtFunctions.lua','shared/Art/PaintingMarkings.lua','client/Properties/ContextSelfNames.lua']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def replace(text,before,after):
    assert text.count(before)==1,(before,text.count(before));return text.replace(before,after,1)
def core(kind,text):
    original={'canvas':'LSCanvasPaintingAction','sculpture':'LSSculptingAction','appraise':'LSCanvasAppraiseAction'}[kind]
    text=text[text.index('local function '):]
    # Class identity is private; source constructors, rates and physical methods remain.
    text=text.replace(original,'Core')
    if kind=='appraise':
        text=replace(text,'return Core','')
        # Original instance scheduling is preserved; repair its one bare global
        # assignment without changing the installed zero-interval repertoire.
        text=replace(text,'\n\t\tsoundTimeInterval = self.soundTime+self.doAnim\n',
                     '\n\t\tself.soundTimeInterval = self.soundTime+self.doAnim\n')
    start=text.index('local function doNote(');end=text.index('\nend',start)+4
    if kind=='canvas':note='local function doNote(character, quality, texture)\n\tlocal choice = ZombRand(2)+1\n\trecordPresentation(character, {quality=quality, texture=texture, noteVariant=choice})\nend'
    elif kind=='sculpture':note='local function doNote(character, quality, texture, known)\n\tlocal choice = ZombRand(2)+1\n\trecordPresentation(character, {quality=quality, texture=texture, known=known, noteVariant=choice})\nend'
    else:note='local function doNote(character, texture, guess, qualityType)\n\trecordPresentation(character, {texture=texture, qualityGuess=guess, qualityType=qualityType})\nend'
    text=text[:start]+note+text[end:]
    # Original UI-only helpers have no remaining caller after the scoped note adaptation.
    start=text.index('local function cleanString(');end=text.index('local function doNote(',start)
    text=text[:start]+text[end:]
    # Cosmetic UI sound uses a private sink; its original random selection remains.
    return 'local '+kind+'Core = (function()\nlocal Core = ISBaseTimedAction:derive("SAONpcArt'+kind+'Core")\n'+text+'\nreturn Core\nend)()\n'
def selection(kind,text):
    if kind=='canvas':
        size=text[text.index('local function getCanvasSize('):text.index('local function getPaintItemsLoot(')]
        main=text[text.index('local function getEaselFacing('):text.index('local function doTransferItem(')]
        main=replace(main,'local newPainting = paintingLib[ZombRand(#paintingLib)+1]','local newPainting = plain(paintingLib[ZombRand(#paintingLib)+1])')
        return 'local selectCanvas = (function()\n'+size+main+'\nreturn getNewPainting\nend)()\n'
    table=text[text.index('local function getArtworkTable('):text.index('local function getMoveableDisplayName(')]
    main=text[text.index('local function getSizeMultiplier('):text.index('local function doTransferItem(')]
    main=replace(main,'local newArtwork = getArtworkFromList(sculptureLib, workOption)','local newArtwork = plain(getArtworkFromList(sculptureLib, workOption))')
    return 'local selectSculpture = (function()\n'+table+main+'\nreturn getNewArtwork\nend)()\n'
def blocks():
    out=[]
    for kind,name in ACTION_FILES.items():out.append((name,core(kind,(SOURCE/name).read_text(encoding='utf-8-sig'))))
    for kind,name in MENU_FILES.items():out.append((name,selection(kind,(SOURCE/name).read_text(encoding='utf-8-sig'))))
    return out
