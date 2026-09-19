SAO={Log={line=function() end},Identity={get=function() return rec end}}
rec={id="audit",verbs={}}
body={x=0,getX=function(self) return self.x end,getY=function() return 0 end}
cancelled=0; calls=0; succeedAt=0
SAOJavaBridge={driveBegin=function() return "DRIVE_STARTED" end,
 tickDrive=function(self,b) calls=calls+1; b.x=b.x+0.1; if calls==succeedAt then return "Succeeded" end; return "Driving" end,
 cancelDrive=function() cancelled=cancelled+1 end}
