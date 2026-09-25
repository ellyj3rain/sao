package com.sao.engine;

import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.io.EOFException;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Dependency-free reader and FP32 evaluator for Speakeasy's versioned
 * coordination bundle.  This class has no Project Zomboid dependency so the
 * exact shipped implementation can be exercised in a headless JVM.
 *
 * <p>The model consumes canonical decision-time JSON bytes plus the sixteen
 * source-owned typed channels.  It neither reads game state nor mutates it.
 * Feasible responses are intersected with the bundle's learned support before
 * softmax, leaving decline and withdraw unavailable until actual target data
 * exists.</p>
 */
public final class SAOCoordinationModel {
    private static final byte[] MAGIC = "SAOCRD01".getBytes(StandardCharsets.US_ASCII);
    private static final int FORMAT_VERSION = 1;
    private static final int MAX_STRING_BYTES = 1_048_576;
    private static final int MAX_COUNT = 16_384;
    private static final String SCHEMA = "speakeasy-native-coordination-bundle";
    private static final String BUNDLE_ID = "r67-r66-coordination-fp32-v1";
    private static final String COMPATIBILITY = "sao-coordination-consumer-v1";
    private static final List<String> EXPECTED_LABELS = List.of(
        "accept", "qualify", "counter-propose", "decline", "defer", "contest",
        "withdraw");
    private static final List<String> EXPECTED_SUPPORT = List.of(
        "accept", "qualify", "counter-propose", "defer", "contest");
    private static final List<String> EXPECTED_UNSUPPORTED = List.of(
        "decline", "withdraw");
    private static final List<String> EXPECTED_FEATURES = List.of(
        "relationship", "absoluteRelationship", "competingPressure",
        "pressureAvailable", "activityIdle", "constraintContest",
        "constraintRepresented", "executionOwnerAvailable", "ownNeedAvailable",
        "destinationKnown", "executorIsZAODriver", "bodyOwnerIsZAO",
        "capabilityAcquire", "capabilityCarry", "capabilityDeliver",
        "capabilityExecute");

    public record Result(String response, Map<String, Float> probabilities,
                         int[] tokenIds) {
        public Result {
            probabilities = Collections.unmodifiableMap(
                new LinkedHashMap<>(probabilities));
            tokenIds = tokenIds.clone();
        }

        @Override
        public int[] tokenIds() {
            return tokenIds.clone();
        }
    }

    private final String bundleSha256;
    private final String bundleId;
    private final String modelSha256;
    private final String datasetSha256;
    private final String tokenizerSha256;
    private final String referenceRunSha256;
    private final String outputConstraint;
    private final Map<String, Integer> specialTokens;
    private final int[][] merges;
    private final List<String> labels;
    private final List<String> observedSupport;
    private final Set<String> observedSupportSet;
    private final List<String> featureNames;
    private final float[][] embeddings;
    private final float[][] adapterWeights;
    private final float[] adapterBiases;
    private final long estimatedBytes;

    private SAOCoordinationModel(String bundleSha256, String bundleId,
            String modelSha256, String datasetSha256, String tokenizerSha256,
            String referenceRunSha256, String outputConstraint,
            Map<String, Integer> specialTokens, int[][] merges,
            List<String> labels, List<String> observedSupport,
            List<String> featureNames, float[][] embeddings,
            float[][] adapterWeights, float[] adapterBiases) {
        this.bundleSha256 = bundleSha256;
        this.bundleId = bundleId;
        this.modelSha256 = modelSha256;
        this.datasetSha256 = datasetSha256;
        this.tokenizerSha256 = tokenizerSha256;
        this.referenceRunSha256 = referenceRunSha256;
        this.outputConstraint = outputConstraint;
        this.specialTokens = Collections.unmodifiableMap(
            new LinkedHashMap<>(specialTokens));
        this.merges = copy(merges);
        this.labels = List.copyOf(labels);
        this.observedSupport = List.copyOf(observedSupport);
        this.observedSupportSet = Collections.unmodifiableSet(
            new LinkedHashSet<>(observedSupport));
        this.featureNames = List.copyOf(featureNames);
        this.embeddings = copy(embeddings);
        this.adapterWeights = copy(adapterWeights);
        this.adapterBiases = adapterBiases.clone();
        this.estimatedBytes = estimateBytes();
    }

    public static SAOCoordinationModel load(byte[] bytes, String expectedSha256)
            throws IOException {
        if (bytes == null || bytes.length == 0) {
            throw new IOException("coordination bundle is empty");
        }
        String actualSha256 = sha256(bytes);
        if (!isSha256(expectedSha256) || !actualSha256.equals(expectedSha256)) {
            throw new IOException("coordination bundle SHA-256 differs");
        }
        try (DataInputStream input = new DataInputStream(
                new ByteArrayInputStream(bytes))) {
            byte[] magic = input.readNBytes(MAGIC.length);
            require(Arrays.equals(magic, MAGIC), "coordination bundle magic differs");
            require(readCount(input, 64) == FORMAT_VERSION,
                "coordination bundle format version differs");
            String schema = readString(input);
            String bundleId = readString(input);
            String parameterPrecision = readString(input);
            String accumulationPrecision = readString(input);
            String softmax = readString(input);
            String compatibility = readString(input);
            String modelSha256 = readString(input);
            String datasetSha256 = readString(input);
            String tokenizerSha256 = readString(input);
            String referenceRunSha256 = readString(input);
            String outputConstraint = readString(input);
            String tokenizerAlgorithm = readString(input);
            String normalization = readString(input);
            String textEncoding = readString(input);
            require(SCHEMA.equals(schema) && BUNDLE_ID.equals(bundleId),
                "coordination bundle identity differs");
            require("fp32".equals(parameterPrecision)
                    && "fp32".equals(accumulationPrecision)
                    && "strict-exp-fp32".equals(softmax),
                "coordination bundle precision differs");
            require(COMPATIBILITY.equals(compatibility),
                "coordination consumer compatibility differs");
            require(isSha256(modelSha256) && isSha256(datasetSha256)
                    && isSha256(tokenizerSha256) && isSha256(referenceRunSha256),
                "coordination source hash is malformed");
            require("intersection-of-current-feasible-and-observed-support".equals(
                    outputConstraint), "coordination output constraint differs");
            require("byte-bpe-ranked-left-to-right-v1".equals(tokenizerAlgorithm)
                    && "none".equals(normalization)
                    && "utf-8-strict".equals(textEncoding),
                "coordination tokenizer contract differs");

            int specialCount = readCount(input, 256);
            Map<String, Integer> specialTokens = new LinkedHashMap<>();
            for (int index = 0; index < specialCount; index++) {
                String name = readString(input);
                int id = readCount(input, 4096);
                require(specialTokens.put(name, id) == null,
                    "duplicate coordination special token");
            }
            require(specialTokens.equals(expectedSpecialTokens()),
                "coordination special token IDs differ");

            int mergeCount = readCount(input, 8192);
            int firstMerge = Collections.max(specialTokens.values()) + 1;
            int[][] merges = new int[mergeCount][2];
            for (int index = 0; index < mergeCount; index++) {
                int replacement = firstMerge + index;
                merges[index][0] = readCount(input, replacement - 1);
                merges[index][1] = readCount(input, replacement - 1);
            }

            List<String> labels = readStrings(input, 256);
            List<String> observedSupport = readStrings(input, 256);
            List<String> unsupported = readStrings(input, 256);
            List<String> featureNames = readStrings(input, 256);
            require(labels.equals(EXPECTED_LABELS)
                    && observedSupport.equals(EXPECTED_SUPPORT)
                    && unsupported.equals(EXPECTED_UNSUPPORTED)
                    && featureNames.equals(EXPECTED_FEATURES),
                "coordination task vocabulary differs");

            float[][] embeddings = readMatrix(input, MAX_COUNT, 256);
            require(embeddings.length == firstMerge + mergeCount
                    && embeddings[0].length == 8,
                "coordination embedding shape differs");
            float[][] adapterWeights = readMatrix(input, 256, 256);
            require(adapterWeights.length == labels.size()
                    && adapterWeights[0].length == 8 + featureNames.size(),
                "coordination adapter shape differs");
            int biasCount = readCount(input, 256);
            require(biasCount == labels.size(),
                "coordination bias shape differs");
            float[] adapterBiases = new float[biasCount];
            for (int index = 0; index < biasCount; index++) {
                adapterBiases[index] = readFloat(input);
            }
            require(input.read() == -1, "coordination bundle has trailing bytes");
            return new SAOCoordinationModel(actualSha256, bundleId, modelSha256,
                datasetSha256, tokenizerSha256, referenceRunSha256,
                outputConstraint, specialTokens, merges, labels,
                observedSupport, featureNames, embeddings, adapterWeights,
                adapterBiases);
        } catch (EOFException exception) {
            throw new IOException("coordination bundle ended early", exception);
        }
    }

    public Result infer(String canonicalJson, float[] typedFeatures,
            List<String> feasibleOptions) {
        if (canonicalJson == null || canonicalJson.isEmpty()
                || canonicalJson.length() > 65_536) {
            throw new IllegalArgumentException("coordination input length is invalid");
        }
        byte[] bytes;
        try {
            ByteBuffer encoded = StandardCharsets.UTF_8.newEncoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
                .encode(java.nio.CharBuffer.wrap(canonicalJson));
            bytes = new byte[encoded.remaining()];
            encoded.get(bytes);
        } catch (CharacterCodingException exception) {
            throw new IllegalArgumentException(
                "coordination input is not strict UTF-8", exception);
        }
        return infer(bytes, typedFeatures, feasibleOptions);
    }

    public Result infer(byte[] canonicalJson, float[] typedFeatures,
            List<String> feasibleOptions) {
        if (canonicalJson == null || canonicalJson.length == 0
                || canonicalJson.length > 262_144) {
            throw new IllegalArgumentException("coordination input bytes are invalid");
        }
        if (typedFeatures == null || typedFeatures.length != featureNames.size()) {
            throw new IllegalArgumentException("coordination typed feature width differs");
        }
        for (float value : typedFeatures) {
            if (!Float.isFinite(value)) {
                throw new IllegalArgumentException(
                    "coordination typed feature is not finite");
            }
        }
        if (feasibleOptions == null || feasibleOptions.isEmpty()
                || feasibleOptions.size() > labels.size()) {
            throw new IllegalArgumentException("coordination feasible options are invalid");
        }
        LinkedHashSet<String> feasible = new LinkedHashSet<>();
        for (String option : feasibleOptions) {
            if (!labels.contains(option) || !feasible.add(option)) {
                throw new IllegalArgumentException(
                    "coordination feasible option is unknown or duplicated");
            }
        }

        int[] tokens = tokenizeInput(canonicalJson);
        int embeddingWidth = embeddings[0].length;
        float[] vector = new float[embeddingWidth + typedFeatures.length];
        for (int token : tokens) {
            requireArgument(token >= 0 && token < embeddings.length,
                "coordination tokenizer emitted an unknown token");
            for (int column = 0; column < embeddingWidth; column++) {
                vector[column] += embeddings[token][column];
            }
        }
        float inverse = 1.0f / (float) tokens.length;
        for (int column = 0; column < embeddingWidth; column++) {
            vector[column] *= inverse;
        }
        System.arraycopy(typedFeatures, 0, vector, embeddingWidth,
            typedFeatures.length);

        float[] logits = new float[labels.size()];
        boolean[] allowed = new boolean[labels.size()];
        float maximum = -Float.MAX_VALUE;
        int allowedCount = 0;
        for (int labelIndex = 0; labelIndex < labels.size(); labelIndex++) {
            String label = labels.get(labelIndex);
            if (!observedSupportSet.contains(label) || !feasible.contains(label)) {
                continue;
            }
            float value = adapterBiases[labelIndex];
            for (int column = 0; column < vector.length; column++) {
                value += adapterWeights[labelIndex][column] * vector[column];
            }
            requireArgument(Float.isFinite(value),
                "coordination logit is not finite");
            logits[labelIndex] = value;
            allowed[labelIndex] = true;
            allowedCount++;
            if (value > maximum) {
                maximum = value;
            }
        }
        requireArgument(allowedCount > 0,
            "coordination mask has no learned feasible response");

        float[] shifted = new float[labels.size()];
        float total = 0.0f;
        for (int labelIndex = 0; labelIndex < labels.size(); labelIndex++) {
            if (allowed[labelIndex]) {
                shifted[labelIndex] = (float) StrictMath.exp(
                    (double) (logits[labelIndex] - maximum));
                total += shifted[labelIndex];
            }
        }
        requireArgument(Float.isFinite(total) && total > 0.0f,
            "coordination softmax total is invalid");
        Map<String, Float> probabilities = new LinkedHashMap<>();
        String response = null;
        float best = -1.0f;
        for (int labelIndex = 0; labelIndex < labels.size(); labelIndex++) {
            if (!allowed[labelIndex]) {
                continue;
            }
            float probability = shifted[labelIndex] / total;
            probabilities.put(labels.get(labelIndex), probability);
            if (probability > best) {
                best = probability;
                response = labels.get(labelIndex);
            }
        }
        return new Result(response, probabilities, tokens);
    }

    public int[] tokenizeInput(byte[] canonicalJson) {
        int[] body = tokenizeBytes(canonicalJson);
        int[] result = new int[body.length + 4];
        result[0] = specialTokens.get("bos");
        result[1] = specialTokens.get("schema");
        result[2] = specialTokens.get("input");
        System.arraycopy(body, 0, result, 3, body.length);
        result[result.length - 1] = specialTokens.get("eos");
        return result;
    }

    public int[] tokenizeBytes(byte[] bytes) {
        if (bytes == null) {
            throw new IllegalArgumentException("coordination tokenizer bytes are absent");
        }
        int[] tokens = new int[bytes.length];
        for (int index = 0; index < bytes.length; index++) {
            tokens[index] = Byte.toUnsignedInt(bytes[index]);
        }
        int firstMerge = Collections.max(specialTokens.values()) + 1;
        for (int mergeIndex = 0; mergeIndex < merges.length; mergeIndex++) {
            int left = merges[mergeIndex][0];
            int right = merges[mergeIndex][1];
            int replacement = firstMerge + mergeIndex;
            int[] output = new int[tokens.length];
            int source = 0;
            int destination = 0;
            while (source < tokens.length) {
                if (source + 1 < tokens.length && tokens[source] == left
                        && tokens[source + 1] == right) {
                    output[destination++] = replacement;
                    source += 2;
                } else {
                    output[destination++] = tokens[source++];
                }
            }
            tokens = Arrays.copyOf(output, destination);
        }
        return tokens;
    }

    public String bundleSha256() { return bundleSha256; }
    public String bundleId() { return bundleId; }
    public String modelSha256() { return modelSha256; }
    public String datasetSha256() { return datasetSha256; }
    public String tokenizerSha256() { return tokenizerSha256; }
    public String referenceRunSha256() { return referenceRunSha256; }
    public String outputConstraint() { return outputConstraint; }
    public List<String> labels() { return labels; }
    public List<String> observedSupport() { return observedSupport; }
    public List<String> featureNames() { return featureNames; }
    public long estimatedBytes() { return estimatedBytes; }

    public static String sha256(byte[] value) throws IOException {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hashed = digest.digest(value);
            StringBuilder text = new StringBuilder(64);
            for (byte item : hashed) {
                text.append(String.format("%02x", Byte.toUnsignedInt(item)));
            }
            return text.toString();
        } catch (NoSuchAlgorithmException exception) {
            throw new IOException("SHA-256 is unavailable", exception);
        }
    }

    private long estimateBytes() {
        long floats = (long) embeddings.length * embeddings[0].length
            + (long) adapterWeights.length * adapterWeights[0].length
            + adapterBiases.length;
        long mergeBytes = (long) merges.length * 2L * Integer.BYTES;
        return floats * Float.BYTES + mergeBytes;
    }

    private static float[][] readMatrix(DataInputStream input, int maxRows,
            int maxColumns) throws IOException {
        int rows = readCount(input, maxRows);
        int columns = readCount(input, maxColumns);
        require(rows > 0 && columns > 0, "coordination matrix is empty");
        float[][] result = new float[rows][columns];
        for (int row = 0; row < rows; row++) {
            for (int column = 0; column < columns; column++) {
                result[row][column] = readFloat(input);
            }
        }
        return result;
    }

    private static float readFloat(DataInputStream input) throws IOException {
        float value = input.readFloat();
        require(Float.isFinite(value), "coordination bundle float is not finite");
        return value;
    }

    private static List<String> readStrings(DataInputStream input, int maximum)
            throws IOException {
        int count = readCount(input, maximum);
        List<String> result = new ArrayList<>(count);
        Set<String> unique = new LinkedHashSet<>();
        for (int index = 0; index < count; index++) {
            String value = readString(input);
            require(unique.add(value), "duplicate coordination string value");
            result.add(value);
        }
        return result;
    }

    private static String readString(DataInputStream input) throws IOException {
        int size = readCount(input, MAX_STRING_BYTES);
        byte[] value = input.readNBytes(size);
        if (value.length != size) {
            throw new EOFException("coordination bundle string ended early");
        }
        try {
            return StandardCharsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(value)).toString();
        } catch (CharacterCodingException exception) {
            throw new IOException("coordination bundle string is not UTF-8", exception);
        }
    }

    private static int readCount(DataInputStream input, int maximum)
            throws IOException {
        int value = input.readInt();
        require(value >= 0 && value <= maximum,
            "coordination bundle count is invalid");
        return value;
    }

    private static Map<String, Integer> expectedSpecialTokens() {
        Map<String, Integer> result = new LinkedHashMap<>();
        result.put("bos", 256);
        result.put("claim-ref", 265);
        result.put("eos", 257);
        result.put("fenced-slot", 266);
        result.put("input", 263);
        result.put("pad", 258);
        result.put("retriever", 260);
        result.put("schema", 262);
        result.put("speaker", 261);
        result.put("target", 264);
        result.put("understander", 259);
        return result;
    }

    private static boolean isSha256(String value) {
        return value != null && value.matches("[0-9a-f]{64}");
    }

    private static void require(boolean condition, String message)
            throws IOException {
        if (!condition) {
            throw new IOException(message);
        }
    }

    private static void requireArgument(boolean condition, String message) {
        if (!condition) {
            throw new IllegalArgumentException(message);
        }
    }

    private static float[][] copy(float[][] source) {
        float[][] result = new float[source.length][];
        for (int index = 0; index < source.length; index++) {
            result[index] = source[index].clone();
        }
        return result;
    }

    private static int[][] copy(int[][] source) {
        int[][] result = new int[source.length][];
        for (int index = 0; index < source.length; index++) {
            result[index] = source[index].clone();
        }
        return result;
    }
}
