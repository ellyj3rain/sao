import contextlib,importlib.util,io,json,pathlib,sys
R=pathlib.Path.cwd();sys.path.insert(0,str(R/'tools'))
cases=[
 ('command_test','SAO.Command.TEACH_MARGIN','SAO.Command.BAD_MARGIN',"the controller's teaching margin is the module's"),
 ('era_test','public static String countyDate(int year','public static String badCountyDate(int year','the record class holds the words'),
 ('world_before_spawn_test','s.countySettled = true','s.countySettled = false',"the flag lives in the county's own store"),
 ('survivor_orders_test','onTheirWord(id, trespasserId,','badWord(id, trespasserId,','the trespass order goes through SAO_Command'),
 ('speech_register_test','SAO.History.stageOf(SAO.History.ageOf(id))','badStage(id)','the child register comes from the stage, not a new field')]
results=[]
for name,needle,replacement,finding in cases:
 spec=importlib.util.spec_from_file_location(name,R/'tools'/f'{name}.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 output=io.StringIO()
 with contextlib.redirect_stdout(output): verdict=m.main()
 assert verdict==0,output.getvalue()
 original=m.read;hits=[]
 def controlled(path):
  s=original(path)
  if needle in s:hits.append(str(path));return s.replace(needle,replacement)
  return s
 m.read=controlled;output=io.StringIO()
 with contextlib.redirect_stdout(output): verdict=m.main()
 assert hits and verdict==1 and 'FAULT: '+finding in output.getvalue(),(name,hits,verdict,output.getvalue())
 results.append({'border':name,'baseline':'pass','source_mutation':needle,'control':'rejected','finding':finding})
 print(name+': baseline passes; source control rejected',flush=True)
(pathlib.Path(__file__).parent/'border-controls-result.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8',newline='\n')
