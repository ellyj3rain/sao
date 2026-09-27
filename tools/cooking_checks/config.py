"""Shared source-root and temporary-output configuration for cooking probes."""
import argparse
import atexit
import os
from pathlib import Path
import tempfile

HERE=Path(__file__).resolve().parent
parser=argparse.ArgumentParser()
parser.add_argument('root',nargs='?',type=Path,default=HERE.parents[1])
parser.add_argument('--output',type=Path)
args=parser.parse_args()
ROOT=args.root.resolve()
COOKING_LUA=Path(os.environ.get("SAO_COOKING_LUA",str(ROOT/"mod/42.20/media/lua/client/SAO_Cooking.lua"))).resolve()
COOKING_JAVA=Path(os.environ.get("SAO_COOKING_JAVA",str(ROOT/"java/src/com/sao/engine/SAOCooking.java"))).resolve()
GAME=Path(os.environ.get('PZ_DIR',r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN',r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
if not (GAME/'projectzomboid.jar').is_file() or not (JDK/'javac.exe').is_file() or not (JDK/'java.exe').is_file():
    print('SKIPPED: installed game and JDK required for cooking proof')
    raise SystemExit(0)
_temporary=tempfile.TemporaryDirectory(prefix='sao-cooking-proof-')
atexit.register(_temporary.cleanup)
OUT=(args.output or Path(_temporary.name)).resolve()
OUT.mkdir(parents=True,exist_ok=True)
