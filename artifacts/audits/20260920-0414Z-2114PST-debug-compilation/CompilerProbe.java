import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;
import zombie.core.Core;
public final class CompilerProbe {
 static final class TrackingReader extends FilterReader {
  int line=1, column=0;
  TrackingReader(Reader r) { super(r); }
  public int read() throws IOException { int ch=super.read(); if(ch=='\n'){line++;column=0;}else column++; return ch; }
  public int read(char[] c,int off,int len) throws IOException { int n=super.read(c,off,len); for(int i=off;i<off+n;i++){if(c[i]=='\n'){line++;column=0;}else column++;} return n; }
 }
 static void dump(Prototype p,String tree) {
  int n=p.locvars==null?-1:p.locvars.length;
  int lo=Integer.MAX_VALUE,hi=0; if(p.lines!=null)for(int line:p.lines){lo=Math.min(lo,line);hi=Math.max(hi,line);}
  System.out.println("PROTO "+tree+" name="+p.name+" lines="+lo+".."+hi+" locals="+n+" maxStack="+p.maxStacksize);
  if(n>=190)for(int i=190;i<n;i++)System.out.println("LOCAL "+tree+" "+i+" "+p.locvars[i]);
  if(p.prototypes!=null)for(int i=0;i<p.prototypes.length;i++)dump(p.prototypes[i],tree+"/"+i);
 }
 public static void main(String[] args) throws Exception {
  Core.debug=Boolean.parseBoolean(args[0]);
  for(Class<?> c:new Class<?>[]{Core.class,LuaCompiler.class,Class.forName("org.luaj.kahluafork.compiler.LexState")})
   System.out.println("CLASS "+c.getName()+" "+c.getProtectionDomain().getCodeSource().getLocation());
  System.out.println("Core.debug="+Core.debug);
  try(TrackingReader r=new TrackingReader(Files.newBufferedReader(Path.of(args[1]),StandardCharsets.UTF_8))) {
   try{LuaClosure c=LuaCompiler.loadis(r,args[1],new J2SEPlatform().newTable());dump(c.prototype,"root");System.out.println("PASS");}
   catch(Throwable t){System.out.println("READ_POSITION line="+r.line+" column="+r.column);t.printStackTrace();System.exit(1);}
  }
 }
}