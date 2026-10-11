/** Installed native enclosure producer over the retained exact native shelter receiver. */
public final class MetalEnclosureNativeProbe {
    public static void main(String[] args)throws Exception {
        System.setProperty("sao.enclosure.probe","true");
        if(args.length>1&&args[1].equals("--frame-movement")){frameMovement(args[0]);return;}
        MetalShelterNativeProbe.main(args);
    }
    private static void check(String name,boolean value){System.out.println("METAL "+name+"="+value);}
    private static Object op(String name,Object a,Object b)throws Exception{
        var m=MetalShelterNativeProbe.class.getDeclaredMethod("op",String.class,Object.class,Object.class);m.setAccessible(true);return m.invoke(null,name,a,b);
    }
    private static Object field(String name)throws Exception{var f=ShelterConstructionNativeProbe.class.getDeclaredField(name);f.setAccessible(true);return f.get(null);}
    private static void frameMovement(String game)throws Exception{
        MetalShelterNativeProbe.main(new String[]{game});
        for(int grade:new int[]{1,2})for(String face:new String[]{"N","W"}){
            String entity="Base.MetalWindowFrameLvl"+grade;op("reset",entity,null);op("face",face,null);op("scene","frame-route-"+grade+face,face);op("seed",entity,null);
            var body=(com.sao.engine.SAOIsoPlayerShell)field("sceneBody");var cell=body.getCell();var square=cell.getGridSquare(10,20,0);
            var other=cell.getGridSquare(face.equals("W")?9:10,face.equals("N")?19:20,0);var frame=square.getWindowThumpableTo(other);
            String prefix="frame_route"+grade+"_"+face+"_";
            check(prefix+"actual_native_window_thumpable",frame!=null&&frame.getEntityScript()!=null&&entity.equals(frame.getEntityScript().getFullName())&&frame.canClimbThrough(body));
            var route=new com.sao.engine.SAORouteState();route.setRoute(java.util.List.of(new float[]{other.getX()+.5f,other.getY()+.5f,0}));route.requested=true;
            var result=com.sao.engine.SAOMovement.tick(body,route);System.out.println("FRAME_ROUTE "+result);
            check(prefix+"native_window_state_admitted",result.equals("Transition:STARTED_WINDOW_CLIMB")&&body.getActionContext().hasEventOccurred("EventClimbWindow"));
            check(prefix+"pending_crossing_retains_route",com.sao.engine.SAOMovement.tick(body,route).equals("Transition:CLIMBING")&&route.routeIndex==0&&route.requested);
        }
        System.out.println("ENCLOSURE COMPLETE");
    }
}
