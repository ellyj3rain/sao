# Crossed representation correction

The operator corrected the claim that Crossed records are represented by native zombies. That wording improperly presented an inconsistent code path as an established second representation of Crossed people.

The established design is unchanged: Crossed retain human appearance, cognition and capabilities under their own constraints. MUTATION.md explicitly distinguishes their living transformation from ordinary reanimation. The supported living conversion preserves the human shell under ZAO execution ownership. Equivalent simulation depth remains required.

The source finding is narrower: ZAO_Controller.tick iterates IsoZombie objects and contains a conditional call to ZAO.Crossed.decide when the corresponding state reports terminalState == crossed. This is a suspect dispatch against the established design. No observation or population audit in this investigation establishes that actual game instances take this path.

CrossedBodyProbe.java establishes only that the built SAO bridge recognizes its human shell and refuses its ordinary movement operation for an allocated IsoZombie. It does not establish the existence, frequency, provenance or intended validity of zombie-bodied Crossed characters. Do not use that probe to justify a new Crossed representation, revival rule or migration policy. Driving has a separate IsoZombie-capable bridge path and must not be conflated with ordinary movement.

The approved social-work plan and its actual approval remain in force. Trace and test the suspect admission as an implementation defect; do not reopen the human-body requirement or infer a new design decision from malformed or inconsistent state. No runtime source changes have been made at this correction point, and the implementation unit remains unfinished.
