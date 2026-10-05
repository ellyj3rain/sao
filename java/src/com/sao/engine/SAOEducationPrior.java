package com.sao.engine;

import java.io.IOException;
import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** Immutable, source-bound conceptual memory. No engine or person cache exists here. */
public final class SAOEducationPrior {
    public static final int TICKS_PER_DAY = 216000;
    public static final int MAX_BYTES = 2 * 1024 * 1024;
    public static final int MAX_REGISTRY_BYTES = 16 * 1024 * 1024;
    private static final Set<String> AUTHORITIES = Set.of("nativeSkillAuthority", "recipeAuthority",
            "currentWorldAuthority", "peerAssentAuthority", "modelTrainingAuthority", "runtimeIntegration");
    private static final Set<String> POLICY_FIELDS = Set.of("schema", "owner", "version", "clock", "ticksPerDay",
            "rates", "familiarityRate", "baseHalfLifeDays", "familiarityHalfLifeMultiplier", "ageDecayPerYear",
            "ageLearningPerYear", "interestLearningBoost", "interestDecayProtection", "practiceProtection",
            "successfulRetrievalProtection", "maximumProtection", "wrongRecallPenalty", "unknownRecallPenalty",
            "assistedRetentionCap", "crossPrimingRate", "maximumPriming", "teacherRetentionThreshold", "interests", "eventLimit");
    private static final Set<String> MODES = Set.of("independent-retrieval", "hinted-retrieval", "tutoring", "passive-learning", "cross-learning");
    private final String rawSha, contentSha, ledgerSha, policySha;
    private final double asOfTick, epochDay, age;
    private final int omitted;
    private final Map<String, Object> policy;
    private final List<Map<String, Object>> concepts;

    public record Bindings(String personId, String profileSha256, String sourceBankSha256,
            String backgroundsSha256, String personEducationSha256,
            String educationalExposuresSha256, String sourceArchiveSha256) {}

    private SAOEducationPrior(String rawSha, String contentSha, String ledgerSha, String policySha,
            double asOfTick, double epochDay, double age, int omitted,
            Map<String, Object> policy, List<Map<String, Object>> concepts) {
        this.rawSha = rawSha; this.contentSha = contentSha; this.ledgerSha = ledgerSha;
        this.policySha = policySha; this.asOfTick = asOfTick; this.epochDay = epochDay;
        this.age = age; this.omitted = omitted; this.policy = policy; this.concepts = concepts;
    }

    public static SAOEducationPrior load(byte[] raw, String trustedRawSha, Bindings expected,
            double countyTick) throws IOException {
        require(raw != null && raw.length > 0 && raw.length <= MAX_BYTES, "payload-size");
        hash(trustedRawSha); require(sha256(raw).equals(trustedRawSha), "raw-hash");
        require(expected != null, "missing-bindings"); identifier(expected.personId());
        for (String value : new String[]{expected.profileSha256(), expected.sourceBankSha256(), expected.backgroundsSha256(),
                expected.personEducationSha256(), expected.educationalExposuresSha256(), expected.sourceArchiveSha256()}) hash(value);
        boundedTime(countyTick);
        String text = StandardCharsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(raw)).toString();
        Map<String, Object> root = object(new Json(text).parse());
        Set<String> fields = new HashSet<>(AUTHORITIES);
        fields.addAll(Set.of("schema", "owner", "ledgerSha256", "asOfTime", "sourceBankSha256", "contextRefs", "policy", "policySha256",
                "startedAt", "ageAtEpoch", "concepts", "omittedConcepts", "standing", "contentSha256"));
        exact(root, fields);
        require("speakeasy-person-educational-runtime-prior/2".equals(root.get("schema")), "prior-schema");
        require("source-reconstructed-person-prior".equals(root.get("standing")), "prior-standing");
        for (String key : AUTHORITIES) require(Boolean.FALSE.equals(root.get(key)), "authority-" + key);
        String contentSha = hash(root.get("contentSha256"));
        Map<String, Object> body = new LinkedHashMap<>(root); body.remove("contentSha256");
        require(sha256(canonical(body).getBytes(StandardCharsets.UTF_8)).equals(contentSha), "content-seal");
        Map<String, Object> owner = object(root.get("owner")); exact(owner, Set.of("kind", "id", "version"));
        require("person".equals(owner.get("kind")) && expected.personId().equals(owner.get("id"))
                && expected.profileSha256().equals(owner.get("version")), "person-profile");
        String bank = hash(root.get("sourceBankSha256")); require(expected.sourceBankSha256().equals(bank), "source-bank");
        Map<String, Object> refs = object(root.get("contextRefs"));
        exact(refs, Set.of("profileSha256", "backgroundsSha256", "personEducationSha256", "educationalExposuresSha256", "sourceArchiveSha256"));
        require(expected.profileSha256().equals(hash(refs.get("profileSha256")))
                && expected.backgroundsSha256().equals(hash(refs.get("backgroundsSha256")))
                && expected.personEducationSha256().equals(hash(refs.get("personEducationSha256")))
                && expected.educationalExposuresSha256().equals(hash(refs.get("educationalExposuresSha256")))
                && expected.sourceArchiveSha256().equals(hash(refs.get("sourceArchiveSha256"))), "context-bindings");
        Map<String, Object> policy = object(root.get("policy")); validatePolicy(policy);
        String policySha = hash(root.get("policySha256"));
        require(sha256(canonical(policy).getBytes(StandardCharsets.UTF_8)).equals(policySha), "policy-seal");
        double atDay = moment(root.get("asOfTime"), policy), epoch = moment(root.get("startedAt"), policy);
        double atTick = "county-tick".equals(policy.get("clock"))
                ? number(object(root.get("asOfTime")).get("value")) : atDay * TICKS_PER_DAY;
        require(atTick <= countyTick && atDay >= epoch, "future-or-pre-epoch");
        double age = number(root.get("ageAtEpoch")); require(age >= 0 && age <= 200, "age-bound");
        int omitted = integer(root.get("omittedConcepts"), 0, 1000000);
        List<Object> rows = array(root.get("concepts")); require(rows.size() <= 128, "concept-bound");
        List<Map<String, Object>> concepts = new ArrayList<>(); Set<String> ids = new HashSet<>();
        for (Object row : rows) {
            Map<String, Object> state = object(row);
            exact(state, Set.of("conceptRef", "courseUnits", "familiarity", "retention", "priming", "calibration",
                    "independentSuccesses", "assistedSuccesses", "usageCount", "lastDay"));
            Map<String, Object> concept = object(state.get("conceptRef"));
            exact(concept, Set.of("id", "source", "exerciseId", "exerciseIndex", "problemSha256", "solutionSha256"));
            String id = identifier(concept.get("id")); require(ids.add(id), "duplicate-concept");
            Map<String, Object> conceptBody = new LinkedHashMap<>(concept); conceptBody.remove("id");
            require(id.equals("source-exercise:" + sha256(canonical(conceptBody).getBytes(StandardCharsets.UTF_8))), "concept-identity");
            source(object(concept.get("source"))); identifier(concept.get("exerciseId"));
            integer(concept.get("exerciseIndex"), 0, 1000000); hash(concept.get("problemSha256")); hash(concept.get("solutionSha256"));
            List<Object> units = array(state.get("courseUnits")); require(units.size() <= 256, "unit-bound");
            Set<String> unitKeys = new HashSet<>();
            for (Object unit : units) {
                Map<String, Object> link = object(unit); exact(link, Set.of("courseId", "unitId", "curriculumRef", "selector"));
                identifier(link.get("courseId")); identifier(link.get("unitId"));
                Map<String, Object> ref = object(link.get("curriculumRef")); exact(ref, Set.of("id", "version", "sha256"));
                identifier(ref.get("id")); identifier(ref.get("version")); hash(ref.get("sha256"));
                Map<String, Object> selector = object(link.get("selector"));
                exact(selector, Set.of("sourcePath", "sourceSha256", "extractionSha256", "startCharacter", "endCharacter", "excerptSha256", "format"));
                Map<String, Object> src = object(concept.get("source"));
                require(src.get("path").equals(selector.get("sourcePath")) && src.get("sha256").equals(selector.get("sourceSha256")), "unit-source-binding");
                hash(selector.get("sourceSha256")); hash(selector.get("extractionSha256")); hash(selector.get("excerptSha256")); identifier(selector.get("format"));
                int start = integer(selector.get("startCharacter"), 0, 1000000000), end = integer(selector.get("endCharacter"), 0, 1000000000);
                require(end > start && unitKeys.add(canonical(link)), "unit-range-or-duplicate");
            }
            for (String key : List.of("familiarity", "retention", "priming")) probability(state.get(key));
            Map<String, Object> calibration = object(state.get("calibration")); exact(calibration, Set.of("correct", "incorrect", "unknown", "estimatedCorrectness"));
            int correct = integer(calibration.get("correct"), 0, 4096), incorrect = integer(calibration.get("incorrect"), 0, 4096);
            integer(calibration.get("unknown"), 0, 4096); double estimation = probability(calibration.get("estimatedCorrectness"));
            require(Math.abs(estimation - (1.0 + correct) / (2.0 + correct + incorrect)) <= 1e-14, "calibration-binding");
            int independent = integer(state.get("independentSuccesses"), 0, 4096), assisted = integer(state.get("assistedSuccesses"), 0, 4096);
            int usage = integer(state.get("usageCount"), 0, 4096), eventLimit = integer(policy.get("eventLimit"), 1, 4096);
            require(independent <= correct && correct + incorrect <= eventLimit && independent + assisted <= eventLimit
                    && usage <= eventLimit && (usage == 0 || independent > 0), "event-counter-binding");
            double lastDay = number(state.get("lastDay")); require(lastDay >= epoch && lastDay <= atDay, "concept-time");
            concepts.add(state);
        }
        return new SAOEducationPrior(trustedRawSha, contentSha, hash(root.get("ledgerSha256")), policySha,
                atTick, epoch, age, omitted, policy, concepts);
    }

    private static void validatePolicy(Map<String, Object> policy) throws IOException {
        exact(policy, POLICY_FIELDS); require("speakeasy-person-learning-policy/1".equals(policy.get("schema")), "policy-schema");
        identifier(policy.get("owner")); identifier(policy.get("version"));
        require("county-day".equals(policy.get("clock")) || "county-tick".equals(policy.get("clock")), "policy-clock");
        for (String key : Set.of("ticksPerDay", "baseHalfLifeDays", "familiarityHalfLifeMultiplier", "maximumProtection")) {
            double value = number(policy.get(key)); require(value > 0 && value <= 1e9, "policy-positive-" + key);
        }
        // Day conversion is explicit, and the policy must name the same county clock owner.
        require(number(policy.get("ticksPerDay")) == TICKS_PER_DAY, "county-clock-conversion");
        require(number(policy.get("maximumProtection")) >= 1, "policy-protection");
        Map<String, Object> rates = object(policy.get("rates")); exact(rates, MODES);
        double independent = probability(rates.get("independent-retrieval"));
        for (String key : MODES) { double value = probability(rates.get(key)); require(key.equals("independent-retrieval") || independent > value, "policy-retrieval-rate"); }
        for (String key : POLICY_FIELDS) if (!Set.of("schema", "owner", "version", "clock", "ticksPerDay", "rates", "interests", "eventLimit",
                "baseHalfLifeDays", "familiarityHalfLifeMultiplier", "maximumProtection").contains(key)) probability(policy.get(key));
        Map<String, Object> interests = object(policy.get("interests")); require(interests.size() <= 512, "interest-bound");
        for (var entry : interests.entrySet()) { identifier(entry.getKey()); probability(entry.getValue()); }
        integer(policy.get("eventLimit"), 1, 4096);
    }

    /** Each query derives from original event states, never from an earlier decayed query. */
    public String snapshotWire(double countyTick) throws IOException {
        boundedTime(countyTick); require(countyTick >= asOfTick, "query-before-import");
        double at = countyTick / TICKS_PER_DAY, personAge = age + Math.max(0, at - epochDay) / 365.2425;
        StringBuilder out = new StringBuilder("SAO_EDUCATION_VIEW_2\t").append(rawSha).append('\t').append(contentSha)
                .append('\t').append(ledgerSha).append('\t').append(asOfTick).append('\t').append(countyTick)
                .append('\t').append(omitted).append('\t').append(concepts.size()).append('\t').append(policySha);
        Map<String, Object> interests = object(policy.get("interests"));
        for (Map<String, Object> state : concepts) {
            Map<String, Object> ref = object(state.get("conceptRef")), src = object(ref.get("source")), calibration = object(state.get("calibration"));
            double interest = 0;
            for (Object unit : array(state.get("courseUnits"))) interest = Math.max(interest, number(interests.getOrDefault(object(unit).get("courseId"), new Numeric("0"))));
            double protection = Math.min(number(policy.get("maximumProtection")), 1 + number(policy.get("practiceProtection")) * number(state.get("usageCount"))
                    + number(policy.get("successfulRetrievalProtection")) * number(state.get("independentSuccesses")) + number(policy.get("interestDecayProtection")) * interest);
            double halfLife = number(policy.get("baseHalfLifeDays")) * protection / (1 + number(policy.get("ageDecayPerYear")) * personAge);
            double elapsed = at - number(state.get("lastDay")); require(elapsed >= 0, "query-before-event");
            double factor = Math.pow(2, -elapsed / halfLife);
            out.append('\n');
            for (Object value : List.of(ref.get("id"), src.get("id"), src.get("version"), src.get("path"))) out.append(escape((String)value)).append('\t');
            out.append(src.get("sha256")).append('\t').append(escape((String)ref.get("exerciseId"))).append('\t')
                    .append(escape(canonical(ref))).append('\t').append(escape(canonical(state.get("courseUnits")))).append('\t')
                    .append(number(state.get("familiarity")) * Math.pow(2, -elapsed / (halfLife * number(policy.get("familiarityHalfLifeMultiplier"))))).append('\t')
                    .append(number(state.get("retention")) * factor).append('\t').append(number(state.get("priming")) * factor).append('\t')
                    .append(number(calibration.get("estimatedCorrectness")));
            for (String key : List.of("correct", "incorrect", "unknown")) out.append('\t').append((int)number(calibration.get(key)));
            for (String key : List.of("independentSuccesses", "assistedSuccesses", "usageCount")) out.append('\t').append((int)number(state.get(key)));
            out.append('\t').append(at);
        }
        require(out.length() <= 3 * MAX_BYTES, "wire-size"); return out.toString();
    }

    public double asOfCountyTick() { return asOfTick; }
    public String rawSha256() { return rawSha; }
    public String contentSha256() { return contentSha; }
    public static String refusalWire(String reason) { return "SAO_EDUCATION_REFUSED_2\t" + escape(reason == null ? "invalid-prior" : reason); }
    /** Complete source registry validation precedes the returned staging port. */
    public static String checkedRegistry(byte[] raw, String trustedRawSha256,
            String worldDefinitionSha256, String sourceBankSha256,
            String sourceArchiveSha256, double countyTick) throws IOException {
        require(raw != null && raw.length > 0 && raw.length <= MAX_REGISTRY_BYTES, "registry-size");
        hash(trustedRawSha256); hash(worldDefinitionSha256); hash(sourceBankSha256); hash(sourceArchiveSha256); boundedTime(countyTick);
        require(sha256(raw).equals(trustedRawSha256), "registry-raw-hash");
        String text=StandardCharsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(raw)).toString();
        Map<String,Object> registry=object(new Json(text,2000000).parse());
        Set<String> fields=new HashSet<>(AUTHORITIES);
        fields.addAll(Set.of("schema","producer","worldOwner","worldDefinitionSha256","sourceBankSha256","sourceArchiveSha256","rows","standing","contentSha256"));
        exact(registry,fields);
        boolean authored = "speakeasy-person-education-runtime-registry/3".equals(registry.get("schema"));
        boolean backgrounds = authored || "speakeasy-person-education-runtime-registry/2".equals(registry.get("schema"));
        require((backgrounds || "speakeasy-person-education-runtime-registry/1".equals(registry.get("schema")))
                && (authored ? "education-runtime-registry-3" : backgrounds ? "education-runtime-registry-2" : "education-runtime-registry-1").equals(registry.get("producer"))
                && "source-reconstructed-explicit-person-registry".equals(registry.get("standing")),"registry-schema");
        for(String flag:AUTHORITIES) require(Boolean.FALSE.equals(registry.get(flag)),"registry-authority");
        require(worldDefinitionSha256.equals(hash(registry.get("worldDefinitionSha256")))
                && sourceBankSha256.equals(hash(registry.get("sourceBankSha256")))
                && sourceArchiveSha256.equals(hash(registry.get("sourceArchiveSha256"))),"registry-source-bindings");
        String contentSha=sealedHash(registry); Map<String,Object> world=object(registry.get("worldOwner"));
        exact(world,Set.of("id","seed")); identifier(world.get("id")); identifier(world.get("seed"));
        List<Object> rows=array(registry.get("rows")); require(rows.size()>0 && rows.size()<=128,"registry-row-bound");
        Set<String> ids=new HashSet<>(); List<String> portRows=new ArrayList<>();
        for(Object item:rows) {
            Map<String,Object> row=object(item);
            Set<String> rowFields = new HashSet<>(Set.of("schema","personId","sourceProfile","sourceProfileSha256","birthProfileProvenance","bindings","prior","rawPriorSha256","contentSha256"));
            if (backgrounds) rowFields.add("backgroundRelations");
            if (authored) rowFields.add("contentExposureHistory");
            exact(row,rowFields);
            require((authored ? "speakeasy-person-education-runtime-registry-row/3" : backgrounds ? "speakeasy-person-education-runtime-registry-row/2" : "speakeasy-person-education-runtime-registry-row/1").equals(row.get("schema")),"registry-row-schema");
            String rowSha=sealedHash(row),id=identifier(row.get("personId")); require(ids.add(id),"registry-duplicate-person");
            Map<String,Object> profile=object(row.get("sourceProfile"));
            exact(profile,Set.of("schema","id","birthYear","asOfYear","birthRegionId","currentRegionId","migrations","collegeYears","electiveCourseIds"));
            require("speakeasy-simulated-education-profile/1".equals(profile.get("schema")) && id.equals(profile.get("id")),"registry-profile-owner");
            int birth=integer(profile.get("birthYear"),1700,1993),asOfYear=integer(profile.get("asOfYear"),birth,1993);
            String birthRegion=identifier(profile.get("birthRegionId")),currentRegion=identifier(profile.get("currentRegionId"));
            integer(profile.get("collegeYears"),0,6); List<Object> electives=array(profile.get("electiveCourseIds"));
            require(electives.size()<=512,"registry-elective-bound"); Set<String> electiveIds=new HashSet<>();
            for(Object elective:electives) require(electiveIds.add(identifier(elective)),"registry-elective-duplicate");
            String residence=birthRegion; int previousYear=birth-1; List<Object> migrations=array(profile.get("migrations"));
            require(migrations.size()<=294,"registry-migration-bound");
            for(Object step:migrations) {
                Map<String,Object> migration=object(step); exact(migration,Set.of("year","fromRegionId","toRegionId"));
                int year=integer(migration.get("year"),birth,asOfYear); String from=identifier(migration.get("fromRegionId")),to=identifier(migration.get("toRegionId"));
                require(year>previousYear && from.equals(residence) && !to.equals(residence),"registry-migration-chain"); residence=to; previousYear=year;
            }
            require(residence.equals(currentRegion),"registry-migration-residence");
            String profileSha=hash(row.get("sourceProfileSha256"));
            require(sha256(canonical(profile).getBytes(StandardCharsets.UTF_8)).equals(profileSha),"registry-profile-hash");
            Map<String,Object> binding=object(row.get("bindings"));
            exact(binding,Set.of("worldSha256","profileSha256","sourceBankSha256","backgroundsSha256","personEducationSha256","educationalExposuresSha256","sourceArchiveSha256"));
            require(worldDefinitionSha256.equals(hash(binding.get("worldSha256"))) && profileSha.equals(hash(binding.get("profileSha256")))
                    && sourceBankSha256.equals(hash(binding.get("sourceBankSha256"))) && sourceArchiveSha256.equals(hash(binding.get("sourceArchiveSha256"))),"registry-row-bindings");
            String backgroundsSha=hash(binding.get("backgroundsSha256")),personSha=hash(binding.get("personEducationSha256")),exposuresSha=hash(binding.get("educationalExposuresSha256"));
            Map<String,Object> provenance=object(row.get("birthProfileProvenance"));
            exact(provenance,Set.of("owner","worldOwner","profileSha256","backgroundsSha256","personEducationSha256"));
            require("speakeasy-source-reconstructed-person-history".equals(provenance.get("owner")) && canonical(world).equals(canonical(provenance.get("worldOwner")))
                    && profileSha.equals(provenance.get("profileSha256")) && backgroundsSha.equals(provenance.get("backgroundsSha256"))
                    && personSha.equals(provenance.get("personEducationSha256")),"registry-birth-provenance");
            Map<String,Object> priorObject=object(row.get("prior")); String priorJson=canonical(priorObject),priorSha=hash(row.get("rawPriorSha256"));
            load(priorJson.getBytes(StandardCharsets.UTF_8),priorSha,new Bindings(id,profileSha,sourceBankSha256,backgroundsSha,personSha,exposuresSha,sourceArchiveSha256),countyTick);
            require(number(priorObject.get("ageAtEpoch"))==asOfYear-birth,"registry-age-profile");
            if (authored && row.get("contentExposureHistory") != null)
                validateExposureHistory(object(row.get("contentExposureHistory")), id, world, profile, binding);
            portRows.add(String.join("\t",escape(id),rowSha,profileSha,Integer.toString(birth),Integer.toString(asOfYear),escape(birthRegion),escape(currentRegion),
                    escape(canonical(profile)),priorSha,escape(priorJson),backgroundsSha,personSha,exposuresSha)
                    + (backgrounds ? "\t" + escape(authored
                        ? authoredBackgroundWire(array(row.get("backgroundRelations")), id, binding, birth, asOfYear, countyTick, row.get("contentExposureHistory"))
                        : backgroundWire(array(row.get("backgroundRelations")), id, binding, birth, asOfYear, countyTick)) : ""));
        }
        String header=String.join("\t",authored ? "SAO_EDUCATION_REGISTRY_3" : backgrounds ? "SAO_EDUCATION_REGISTRY_2" : "SAO_EDUCATION_REGISTRY_1",trustedRawSha256,contentSha,worldDefinitionSha256,sourceBankSha256,sourceArchiveSha256,
                Integer.toString(rows.size()),escape(canonical(world)));
        String port=header+"\n"+String.join("\n",portRows); require(port.length()<=3*MAX_REGISTRY_BYTES,"registry-port-bound"); return port;
    }
    /** Versioned semantic adapter. A bound historical exposure is a premise,
     * never a skill, present object, food supply or successful action. */
    private static String backgroundWire(List<Object> meanings, String personId,
            Map<String,Object> bindings, int birth, int asOfYear, double tick) throws IOException {
        require(meanings.size() <= 16, "background-bound");
        List<String> rows = new ArrayList<>(); Set<String> seen = new HashSet<>();
        for (Object value : meanings) {
            Map<String,Object> meaning = object(value);
            exact(meaning, Set.of("schema","meaningId","personId","bindings","curriculumRef","courseId","unitId",
                    "sourceId","sourceVersion","selector","publicationYear","statementText","statementSha256",
                    "relations","conditions","acquisition","admittedAtTick","standing","contentSha256"));
            String identity = sealedHash(meaning);
            require(seen.add(identity) && "sao-person-background-meaning/1".equals(meaning.get("schema"))
                    && "household-stove-cooking-1".equals(meaning.get("meaningId"))
                    && "defeasible-exposure-prior; retention-and-mastery-unassessed".equals(meaning.get("standing")), "background-schema");
            require(personId.equals(meaning.get("personId")) && canonical(bindings).equals(canonical(meaning.get("bindings"))), "background-person-binding");
            require("grade-8-practical-arts".equals(meaning.get("courseId"))
                    && "household-science-90255-95959-grade-8-practical-arts".equals(meaning.get("unitId"))
                    && "household-science".equals(meaning.get("sourceId"))
                    && "33e8491494dcac35876eb50d5a7d88afeac456d75b2681e897914a7c81389017".equals(meaning.get("sourceVersion")), "background-source-unit");
            Map<String,Object> curriculum = object(meaning.get("curriculumRef"));
            exact(curriculum,Set.of("id","version","sha256")); identifier(curriculum.get("id")); identifier(curriculum.get("version")); hash(curriculum.get("sha256"));
            Map<String,Object> selector = object(meaning.get("selector"));
            exact(selector,Set.of("sourcePath","sourceSha256","extractionSha256","startCharacter","endCharacter","excerptSha256","format"));
            require("household-science/source.txt".equals(selector.get("sourcePath"))
                    && meaning.get("sourceVersion").equals(selector.get("sourceSha256"))
                    && "8ec52c2ca01db3ab41efe5880e09f1cf9fa413044395d11291564fb8a7661ace".equals(selector.get("extractionSha256"))
                    && number(selector.get("startCharacter")) == 90255 && number(selector.get("endCharacter")) == 95959
                    && "133674f9302cf1d783ff89f5106d0e0d5d22d5ecf6df3e14fab0ddda589a9940".equals(selector.get("excerptSha256"))
                    && "plain-text".equals(selector.get("format")), "background-selector");
            String statement = identifier(meaning.get("statementText"));
            require("06cc5b650dd18f29bbcb0672e0650adfc8aac5ed1fc1d0a70666685f2ab6dd3e".equals(hash(meaning.get("statementSha256")))
                    && meaning.get("statementSha256").equals(sha256(statement.getBytes(StandardCharsets.UTF_8))), "background-literal-content");
            require(number(meaning.get("publicationYear")) == 1918, "background-publication");
            Map<String,Object> acquisition = object(meaning.get("acquisition"));
            exact(acquisition,Set.of("kind","receiptSha256","personId","profileSha256","startYear","endYear","ageAtStart",
                    "regionId","cohortId","institutionId","unitId","attended"));
            require("generated-schooling-exposure".equals(acquisition.get("kind"))
                    && personId.equals(acquisition.get("personId")) && bindings.get("profileSha256").equals(acquisition.get("profileSha256"))
                    && meaning.get("unitId").equals(acquisition.get("unitId")) && Boolean.TRUE.equals(acquisition.get("attended")), "background-acquisition");
            hash(acquisition.get("receiptSha256"));
            for (String field : List.of("regionId","cohortId","institutionId")) identifier(acquisition.get(field));
            int start = integer(acquisition.get("startYear"), Math.max(birth,1918), asOfYear);
            int end = integer(acquisition.get("endYear"), start + 1, asOfYear);
            require(number(acquisition.get("ageAtStart")) == start - birth, "background-developmental-time");
            double admitted = number(meaning.get("admittedAtTick")); boundedTime(admitted);
            require(admitted <= tick, "background-future");
            List<Object> conditions = array(meaning.get("conditions"));
            require(conditions.equals(List.of("suitable-food","usable-heating-means","permission")), "background-conditions");
            List<Object> relations = array(meaning.get("relations")); require(relations.size() == 2, "background-relations");
            String[][] expected = {{"stove","affords","cooking"},{"cooking","supports","eating"}};
            for (int i = 0; i < 2; i++) {
                Map<String,Object> relation = object(relations.get(i)); exact(relation,Set.of("from","relation","into"));
                require(expected[i][0].equals(relation.get("from")) && expected[i][1].equals(relation.get("relation"))
                        && expected[i][2].equals(relation.get("into")), "background-meaning");
                List<String> fields = List.of(identity + ":" + i, expected[i][0], expected[i][1], expected[i][2],
                        (String)meaning.get("sourceId"), (String)meaning.get("sourceVersion"), (String)selector.get("sourcePath"),
                        (String)selector.get("excerptSha256"), (String)meaning.get("unitId"), (String)curriculum.get("sha256"),
                        (String)acquisition.get("receiptSha256"), Integer.toString(start), Integer.toString(end),
                        (String)acquisition.get("regionId"), (String)acquisition.get("cohortId"), (String)acquisition.get("institutionId"),
                        Double.toString(admitted), (String)meaning.get("statementSha256"));
                List<String> escaped = new ArrayList<>(); for (String field : fields) escaped.add(escape(field));
                rows.add(String.join("\t",escaped));
            }
        }
        return String.join("\n",rows);
    }
    // Reviewed projections are content pins, not an occupation or culture ontology.
    // Adding a projection requires retaining its literal source and an admitted carrier.
    private static final Set<String> EXPOSURE_PROJECTIONS = Set.of(
        "652c1bd22d539a4942bff208ac07130777806294c50fae6234d03f0af3e08c01",
        "7108b5f145e5eb650be92c2eeb50bdbba382a2c74605509d56358885ae4279ca",
        "119583005f9e633891f5161c76e3fb5f9f687bb28fa6ac24cce9c4a3a98cca6f");
    private static final Set<String> EXPOSURE_AUTHORITY = Set.of("personalRetentionAuthority", "nativeSkillAuthority",
        "currentWorldAuthority", "peerAssentAuthority", "trainingApprovalAuthority");
    private static void exposureFields(Map<String,Object> value, Set<String> fields) throws IOException {
        Set<String> all = new HashSet<>(fields); all.addAll(EXPOSURE_AUTHORITY); exact(value, all);
        for (String field : EXPOSURE_AUTHORITY) require(Boolean.FALSE.equals(value.get(field)), "exposure-authority");
        sealedHash(value);
    }
    private static void exposureRefs(Object raw, Map<String,Object> binding) throws IOException {
        Map<String,Object> refs = object(raw);
        exact(refs, Set.of("profileSha256", "backgroundsSha256", "personEducationSha256", "educationalExposuresSha256", "sourceArchiveSha256"));
        for (String key : refs.keySet()) require(hash(refs.get(key)).equals(binding.get(key)), "exposure-context-binding");
    }
    private static void validateExposureHistory(Map<String,Object> history, String id, Map<String,Object> world,
            Map<String,Object> profile, Map<String,Object> binding) throws IOException {
        exposureFields(history, Set.of("schema", "producer", "personId", "contextRefs", "authoredHistory", "receipts", "standing", "contentSha256"));
        require("speakeasy-authored-content-exposures/1".equals(history.get("schema"))
            && "education-content-exposures-1".equals(history.get("producer"))
            && id.equals(history.get("personId")) && "authored-person-history".equals(history.get("standing")), "exposure-history-schema");
        exposureRefs(history.get("contextRefs"), binding);
        Map<String,Object> authored = object(history.get("authoredHistory"));
        exact(authored, Set.of("schema", "personId", "worldOwner", "profileSha256", "personEducationSha256", "events"));
        require("speakeasy-authored-content-exposure-history/1".equals(authored.get("schema")) && id.equals(authored.get("personId"))
            && canonical(world).equals(canonical(authored.get("worldOwner")))
            && binding.get("profileSha256").equals(authored.get("profileSha256"))
            && binding.get("personEducationSha256").equals(authored.get("personEducationSha256")), "exposure-history-binding");
        List<Object> events = array(authored.get("events")), receipts = array(history.get("receipts"));
        require(events.size() <= 32 && receipts.size() == events.size(), "exposure-event-bound");
        Set<String> ids = new HashSet<>();
        int birth = integer(profile.get("birthYear"),1700,1993), asOf = integer(profile.get("asOfYear"),birth,1993);
        String authoredSha = sha256(canonical(authored).getBytes(StandardCharsets.UTF_8));
        for (int i=0; i<events.size(); i++) {
            Map<String,Object> event=object(events.get(i)), receipt=object(receipts.get(i));
            exact(event, Set.of("id", "kind", "channel", "carrierId", "regionId", "startYear", "endYear", "curriculumRef", "courseId", "unitId"));
            require(ids.add(identifier(event.get("id"))), "exposure-event-duplicate");
            require(Set.of("work-training", "community-literary").contains(event.get("kind"))
                && Set.of("read", "heard", "guided-practice").contains(event.get("channel")), "exposure-event-channel");
            for (String key : List.of("carrierId", "regionId", "courseId", "unitId")) identifier(event.get(key));
            int start=integer(event.get("startYear"),birth,asOf), end=integer(event.get("endYear"),start+1,asOf);
            String residence=(String)profile.get("birthRegionId");
            for (Object step : array(profile.get("migrations"))) {
                Map<String,Object> migration=object(step); int year=(int)number(migration.get("year"));
                require(!(start < year && year < end), "exposure-region-crossing");
                if (year <= start) residence=(String)migration.get("toRegionId");
            }
            require(residence.equals(event.get("regionId")), "exposure-region-binding");
            Map<String,Object> curriculum=object(event.get("curriculumRef"));
            exact(curriculum,Set.of("id","version","sha256")); identifier(curriculum.get("id")); identifier(curriculum.get("version")); hash(curriculum.get("sha256"));
            exposureFields(receipt,Set.of("schema","producer","personId","worldOwner","contextRefs","authoredHistorySha256","event","unit","ageAtStart","standing","contentSha256"));
            require("speakeasy-authored-content-exposure/1".equals(receipt.get("schema"))
                && "education-content-exposures-1".equals(receipt.get("producer")) && id.equals(receipt.get("personId"))
                && canonical(world).equals(canonical(receipt.get("worldOwner")))
                && authoredSha.equals(receipt.get("authoredHistorySha256")) && canonical(event).equals(canonical(receipt.get("event")))
                && number(receipt.get("ageAtStart"))==start-birth
                && "authored-exposure; retention-mastery-and-assent-unassessed".equals(receipt.get("standing")), "exposure-receipt-binding");
            exposureRefs(receipt.get("contextRefs"), binding);
            Map<String,Object> unit=object(receipt.get("unit"));
            require(event.get("unitId").equals(unit.get("id")), "exposure-unit-binding");
            integer(unit.get("editionYear"), 0, start);
        }
    }
    private static String authoredBackgroundWire(List<Object> meanings, String id, Map<String,Object> bindings,
            int birth, int asOfYear, double tick, Object historyRaw) throws IOException {
        require(meanings.size() <= 16, "background-bound");
        List<String> rows=new ArrayList<>(); Set<String> seen=new HashSet<>();
        for (Object raw : meanings) {
            Map<String,Object> meaning=object(raw);
            String identity=sealedHash(meaning);
            require(seen.add(identity), "background-duplicate-meaning");
            if ("sao-person-background-meaning/1".equals(meaning.get("schema"))) {
                String legacy=backgroundWire(List.of(raw),id,bindings,birth,asOfYear,tick);
                for (String line:legacy.split("\n")) rows.add(line);
                continue;
            }
            exact(meaning,Set.of("schema","personId","bindings","projection","projectionSha256","contentExposureHistorySha256",
                "acquisition","admittedAtTick","standing","contentSha256"));
            require("sao-person-background-meaning/2".equals(meaning.get("schema"))
                && "defeasible-exposure-prior; retention-mastery-and-assent-unassessed".equals(meaning.get("standing")), "authored-meaning-schema");
            require(id.equals(meaning.get("personId")) && canonical(bindings).equals(canonical(meaning.get("bindings"))), "authored-meaning-person");
            Map<String,Object> history=object(historyRaw), receipt=object(meaning.get("acquisition"));
            String historySha=sealedHash(history), receiptSha=sealedHash(receipt);
            require(historySha.equals(meaning.get("contentExposureHistorySha256"))
                && array(history.get("receipts")).stream().anyMatch(r -> r.equals(receipt)), "authored-meaning-receipt");
            Map<String,Object> projection=object(meaning.get("projection"));
            String projectionSha=sha256(canonical(projection).getBytes(StandardCharsets.UTF_8));
            require(EXPOSURE_PROJECTIONS.contains(projectionSha) && projectionSha.equals(meaning.get("projectionSha256")), "authored-projection-pin");
            Map<String,Object> event=object(receipt.get("event")), unit=object(projection.get("unit")), selector=object(unit.get("selector"));
            require(canonical(unit).equals(canonical(receipt.get("unit"))) && projection.get("courseId").equals(event.get("courseId")), "authored-projection-source");
            double admitted=number(meaning.get("admittedAtTick")); boundedTime(admitted);
            require(admitted <= tick, "authored-meaning-future");
            Map<String,Object> curriculum=object(event.get("curriculumRef"));
            String basis="work-training".equals(event.get("kind")) ? "authored-work-training-exposure" : "authored-community-literary-exposure";
            List<String> conditions=new ArrayList<>(); for(Object condition:array(projection.get("conditions"))) conditions.add(identifier(condition));
            int index=0;
            for (Object relationRaw:array(projection.get("relations"))) {
                Map<String,Object> relation=object(relationRaw);
                List<String> fields=List.of(identity+":"+(index++),(String)relation.get("from"),(String)relation.get("relation"),(String)relation.get("into"),
                    (String)unit.get("sourceId"),(String)unit.get("sourceVersion"),(String)selector.get("sourcePath"),(String)selector.get("excerptSha256"),
                    (String)unit.get("id"),(String)curriculum.get("sha256"),receiptSha,Integer.toString((int)number(event.get("startYear"))),
                    Integer.toString((int)number(event.get("endYear"))),(String)event.get("regionId"),"authored-event",(String)event.get("carrierId"),
                    Double.toString(admitted),(String)projection.get("statementSha256"),basis,String.join(";",conditions),(String)projection.get("contentRole"),
                    (String)event.get("id"),historySha,(String)event.get("channel"));
                List<String> escaped=new ArrayList<>();for(String field:fields)escaped.add(escape(field));rows.add(String.join("\t",escaped));
            }
        }
        return String.join("\n",rows);
    }
    private static String sealedHash(Map<String,Object> value) throws IOException {
        String expected=hash(value.get("contentSha256")); Map<String,Object> body=new LinkedHashMap<>(value); body.remove("contentSha256");
        require(sha256(canonical(body).getBytes(StandardCharsets.UTF_8)).equals(expected),"registry-content-seal"); return expected;
    }
    /** Validates detached reference consistency, without certifying who supplied a view. */
    public static boolean checkConceptView(String conceptRefJson, String courseUnitsJson,
            String conceptId, String sourceId, String sourceVersion, String sourcePath,
            String sourceSha256, String exerciseId) {
        try {
            require(conceptRefJson != null && conceptRefJson.length() <= 262144
                    && courseUnitsJson != null && courseUnitsJson.length() <= 262144, "concept-view-bound");
            Map<String, Object> ref = object(new Json(conceptRefJson).parse());
            exact(ref, Set.of("id", "source", "exerciseId", "exerciseIndex", "problemSha256", "solutionSha256"));
            require(identifier(conceptId).equals(ref.get("id")) && identifier(exerciseId).equals(ref.get("exerciseId")), "concept-view-identity");
            Map<String, Object> body = new LinkedHashMap<>(ref); body.remove("id");
            require(conceptId.equals("source-exercise:" + sha256(canonical(body).getBytes(StandardCharsets.UTF_8))), "concept-view-seal");
            integer(ref.get("exerciseIndex"),0,1000000); hash(ref.get("problemSha256")); hash(ref.get("solutionSha256"));
            Map<String, Object> src = object(ref.get("source")); source(src);
            require(identifier(sourceId).equals(src.get("id")) && identifier(sourceVersion).equals(src.get("version"))
                    && identifier(sourcePath).equals(src.get("path")) && hash(sourceSha256).equals(src.get("sha256")), "concept-view-source");
            List<Object> units = array(new Json(courseUnitsJson).parse()); require(units.size() <= 256, "concept-view-units");
            Set<String> identities = new HashSet<>();
            for(Object value: units) {
                Map<String,Object> unit=object(value); exact(unit,Set.of("courseId","unitId","curriculumRef","selector"));
                identifier(unit.get("courseId")); identifier(unit.get("unitId"));
                Map<String,Object> curriculum=object(unit.get("curriculumRef")); exact(curriculum,Set.of("id","version","sha256"));
                identifier(curriculum.get("id")); identifier(curriculum.get("version")); hash(curriculum.get("sha256"));
                Map<String,Object> selector=object(unit.get("selector"));
                exact(selector,Set.of("sourcePath","sourceSha256","extractionSha256","startCharacter","endCharacter","excerptSha256","format"));
                require(sourcePath.equals(selector.get("sourcePath")) && sourceSha256.equals(selector.get("sourceSha256")), "concept-view-selector");
                hash(selector.get("extractionSha256")); hash(selector.get("excerptSha256")); identifier(selector.get("format"));
                int start=integer(selector.get("startCharacter"),0,1000000000),end=integer(selector.get("endCharacter"),0,1000000000);
                require(end>start && identities.add(canonical(unit)),"concept-view-unit-range");
            }
            return true;
        } catch(IOException | RuntimeException invalid) { return false; }
    }
    public static String decodeWireField(String encoded) throws IOException {
        return decodeField(encoded,262144);
    }
    public static String decodeRegistryField(String encoded) throws IOException {
        return decodeField(encoded,3*MAX_BYTES);
    }
    private static String decodeField(String encoded,int bound) throws IOException {
        require(encoded != null && encoded.length() <= bound, "wire-field-bound");
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        for (int i=0;i<encoded.length();i++) {
            char c=encoded.charAt(i);
            if (c=='%') {
                require(i+2<encoded.length() && encoded.substring(i+1,i+3).matches("[0-9A-F]{2}"), "wire-field-escape");
                bytes.write(Integer.parseInt(encoded.substring(i+1,i+3),16)); i+=2;
            } else { require(c>=33 && c<=126, "wire-field-ascii"); bytes.write(c); }
        }
        return StandardCharsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(bytes.toByteArray())).toString();
    }
    private static String escape(String text) {
        StringBuilder out = new StringBuilder();
        for (byte value : text.getBytes(StandardCharsets.UTF_8)) {
            int c = value & 255;
            if (c >= 33 && c <= 126 && c != '%') out.append((char)c);
            else out.append('%').append("0123456789ABCDEF".charAt(c >>> 4)).append("0123456789ABCDEF".charAt(c & 15));
        }
        return out.toString();
    }
    private static double moment(Object value, Map<String, Object> policy) throws IOException {
        Map<String, Object> time = object(value); exact(time, Set.of("clock", "value")); require(policy.get("clock").equals(time.get("clock")), "time-clock");
        double v = number(time.get("value")); require(v >= 0 && v <= 1e12, "time-bound");
        return v / ("county-tick".equals(time.get("clock")) ? number(policy.get("ticksPerDay")) : 1);
    }
    private static void boundedTime(double value) throws IOException { require(Double.isFinite(value) && value >= 0 && value <= 1e12, "county-time-bound"); }
    private static void source(Map<String, Object> source) throws IOException { exact(source, Set.of("id", "version", "path", "sha256")); identifier(source.get("id")); identifier(source.get("version")); identifier(source.get("path")); hash(source.get("sha256")); }
    private static String identifier(Object value) throws IOException { require(value instanceof String && !((String)value).isBlank() && ((String)value).length() <= 32768, "identifier"); return (String)value; }
    private static String hash(Object value) throws IOException { require(value instanceof String && ((String)value).matches("[a-f0-9]{64}"), "sha256-format"); return (String)value; }
    private static double probability(Object value) throws IOException { double n = number(value); require(n >= 0 && n <= 1, "probability"); return n; }
    private static double number(Object value) throws IOException { require(value instanceof Numeric, "number-type"); double n = Double.parseDouble(((Numeric)value).token); require(Double.isFinite(n), "finite-number"); return n; }
    private static int integer(Object value, int min, int max) throws IOException { double n = number(value); require(n == Math.rint(n) && n >= min && n <= max && !((Numeric)value).token.contains(".") && !((Numeric)value).token.toLowerCase().contains("e"), "integer-bound"); return (int)n; }
    @SuppressWarnings("unchecked") private static Map<String, Object> object(Object value) throws IOException { require(value instanceof Map, "object-type"); return (Map<String, Object>)value; }
    @SuppressWarnings("unchecked") private static List<Object> array(Object value) throws IOException { require(value instanceof List, "array-type"); return (List<Object>)value; }
    private static void exact(Map<String, Object> object, Set<String> fields) throws IOException { require(object.keySet().equals(fields), "object-fields"); }
    private static void require(boolean condition, String reason) throws IOException { if (!condition) throw new IOException(reason); }
    public static String sha256(byte[] bytes) throws IOException { try { byte[] digest = MessageDigest.getInstance("SHA-256").digest(bytes); StringBuilder out = new StringBuilder(); for (byte b : digest) out.append(String.format("%02x", b & 255)); return out.toString(); } catch (NoSuchAlgorithmException e) { throw new IOException("sha256-unavailable", e); } }
    private record Numeric(String token) {}

    // Numeric lexical forms are retained so Python's sealed JSON bytes survive parsing.
    private static String canonical(Object value) throws IOException {
        if (value == null) return "null";
        if (value instanceof String s) return quote(s);
        if (value instanceof Boolean || value instanceof Numeric) return value instanceof Numeric n ? n.token : value.toString();
        if (value instanceof List<?> list) { List<String> values = new ArrayList<>(); for (Object child : list) values.add(canonical(child)); return "[" + String.join(",", values) + "]"; }
        Map<String, Object> map = object(value); List<String> keys = new ArrayList<>(map.keySet());
        keys.sort((a,b) -> { int[] x=a.codePoints().toArray(), y=b.codePoints().toArray(); for(int i=0;i<Math.min(x.length,y.length);i++) if(x[i]!=y[i]) return Integer.compare(x[i],y[i]); return Integer.compare(x.length,y.length); });
        List<String> entries = new ArrayList<>(); for (String key : keys) entries.add(quote(key) + ":" + canonical(map.get(key))); return "{" + String.join(",", entries) + "}";
    }
    private static String quote(String value) { StringBuilder out = new StringBuilder("\""); for (int i=0;i<value.length();i++) { char c=value.charAt(i); switch(c) { case '"' -> out.append("\\\""); case '\\' -> out.append("\\\\"); case '\b' -> out.append("\\b"); case '\f' -> out.append("\\f"); case '\n' -> out.append("\\n"); case '\r' -> out.append("\\r"); case '\t' -> out.append("\\t"); default -> { if(c<32) out.append(String.format("\\u%04x",(int)c)); else out.append(c); } } } return out.append('"').toString(); }
    private static final class Json {
        private final String text; private final int maxNodes; private int pos, nodes;
        Json(String text) { this(text,100000); }
        Json(String text,int maxNodes) { this.text=text; this.maxNodes=maxNodes; }
        Object parse() throws IOException { Object value=value(0); whitespace(); require(pos==text.length(), "json-trailing"); return value; }
        private void whitespace() { while(pos<text.length() && " \t\n\r".indexOf(text.charAt(pos))>=0) pos++; }
        private Object value(int depth) throws IOException {
            require(depth<=16 && ++nodes<=maxNodes, "json-bound"); whitespace(); require(pos<text.length(), "json-end"); char c=text.charAt(pos);
            if(c=='"') return string();
            if(c=='{') { pos++; Map<String,Object> map=new LinkedHashMap<>(); whitespace(); if(take('}')) return map; do { whitespace(); require(pos<text.length() && text.charAt(pos)=='"', "json-key"); String key=string(); require(!map.containsKey(key), "json-duplicate"); whitespace(); require(take(':'), "json-colon"); map.put(key,value(depth+1)); whitespace(); if(take('}')) return map; require(take(','), "json-comma"); } while(true); }
            if(c=='[') { pos++; List<Object> list=new ArrayList<>(); whitespace(); if(take(']')) return list; do { list.add(value(depth+1)); whitespace(); if(take(']')) return list; require(take(','), "json-comma"); } while(true); }
            for(String literal:List.of("true","false","null")) if(text.startsWith(literal,pos)) { pos+=literal.length(); return literal.equals("null")?null:Boolean.valueOf(literal); }
            int start=pos; if(take('-')) require(pos<text.length(),"json-number"); require(pos<text.length() && Character.isDigit(text.charAt(pos)),"json-number");
            if(take('0')) { require(pos==text.length() || !Character.isDigit(text.charAt(pos)),"json-leading-zero"); } else { require(text.charAt(pos)>='1' && text.charAt(pos)<='9',"json-number"); while(pos<text.length() && Character.isDigit(text.charAt(pos))) pos++; }
            if(take('.')) { int digits=pos; while(pos<text.length() && Character.isDigit(text.charAt(pos))) pos++; require(pos>digits,"json-fraction"); }
            if(pos<text.length() && (text.charAt(pos)=='e'||text.charAt(pos)=='E')) { pos++; if(pos<text.length() && (text.charAt(pos)=='+'||text.charAt(pos)=='-')) pos++; int digits=pos; while(pos<text.length() && Character.isDigit(text.charAt(pos))) pos++; require(pos>digits,"json-exponent"); }
            require(pos-start<=128,"json-number-bound"); Numeric n=new Numeric(text.substring(start,pos)); number(n); return n;
        }
        private boolean take(char c) { if(pos<text.length() && text.charAt(pos)==c) { pos++; return true; } return false; }
        private String string() throws IOException {
            require(take('"'),"json-string"); StringBuilder out=new StringBuilder();
            while(pos<text.length()) { char c=text.charAt(pos++); if(c=='"') { require(out.length()<=32768,"json-string-bound"); String s=out.toString(); for(int i=0;i<s.length();i++) if(Character.isSurrogate(s.charAt(i))) { require(Character.isHighSurrogate(s.charAt(i)) && i+1<s.length() && Character.isLowSurrogate(s.charAt(i+1)),"json-surrogate"); i++; } return s; } require(c>=32,"json-control"); if(c=='\\') { require(pos<text.length(),"json-escape"); c=text.charAt(pos++); switch(c) { case '"','\\','/' -> out.append(c); case 'b' -> out.append('\b'); case 'f' -> out.append('\f'); case 'n' -> out.append('\n'); case 'r' -> out.append('\r'); case 't' -> out.append('\t'); case 'u' -> { require(pos+4<=text.length(),"json-unicode"); String hex=text.substring(pos,pos+4); require(hex.matches("[0-9a-fA-F]{4}"),"json-unicode"); out.append((char)Integer.parseInt(hex,16)); pos+=4; } default -> throw new IOException("json-escape"); } } else out.append(c); require(out.length()<=32768,"json-string-bound"); }
            throw new IOException("json-string-end");
        }
    }
}
