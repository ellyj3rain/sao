    private static final class MaterialInfo extends zombie.world.ItemInfo {
        MaterialInfo(zombie.scripting.objects.Item item,short id) {
            name=item.getName();moduleName=item.getModule().getName();fullType=item.getFullName();
            registryId=id;isLoaded=true;scriptItem=item;entityScript=item;modId="fixture-installed-source";
        }
    }
    private static final class MaterialDictionary extends zombie.world.DictionaryData {
        void register(zombie.scripting.objects.Item item,short id) {
            var info=new MaterialInfo(item,id);itemIdToInfoMap.put(id,info);itemTypeToInfoMap.put(info.getFullType(),info);
        }
    }
    private static InventoryItem material(Path file,String moduleName,String name,short id,MaterialDictionary dictionary)throws Exception {
        String text=zombie.scripting.ScriptParser.stripComments(Files.readString(file));
        var match=java.util.regex.Pattern.compile("\\bitem\\s+"+java.util.regex.Pattern.quote(name)+"\\s*\\{").matcher(text);
        if(!match.find())throw new AssertionError("Installed item missing "+name);
        int end=match.end(),depth=1;while(depth>0&&end<text.length()){char c=text.charAt(end++);if(c=='{')depth++;else if(c=='}')depth--;}
        if(depth!=0)throw new AssertionError("Unclosed installed item "+name);
        var module=ScriptManager.instance.moduleMap.get(moduleName);
        if(module==null){module=new zombie.scripting.objects.ScriptModule();module.name=moduleName;ScriptManager.instance.moduleMap.put(moduleName,module);ScriptManager.instance.moduleList.add(module);}
        var definition=new zombie.scripting.objects.Item();definition.setModule(module);definition.setName(name);
        definition.Load(name,text.substring(match.start(),end));definition.setRegistry_id(id);
        module.items.getScriptMap().put(name,definition);dictionary.register(definition,id);
        var bucketsField=ScriptManager.class.getDeclaredField("items");bucketsField.setAccessible(true);
        var buckets=(zombie.scripting.ScriptBucketCollection<zombie.scripting.objects.Item>)bucketsField.get(ScriptManager.instance);
        buckets.registerModule(module);buckets.getFullTypeToScriptMap().put(definition.getFullName(),definition);
        var value=zombie.inventory.InventoryItemFactory.CreateItem(definition.getFullName());
        if(value==null)throw new AssertionError("Native item creation failed "+definition.getFullName());
        value.setID(id);value.setName(name);return value;
    }
